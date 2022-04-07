FROM maven:3.5-jdk-8 as builder

ENV ZEPPELIN_VERSION=0.10.1

ARG ZEPPELIN_BUILD_NAME='without-hadoop'

ARG ZEPPELIN_SOURCE=/tmp/zeppelin/src
ARG ZEPPELIN_SRC_URL=https://github.com/apache/zeppelin/archive/v${ZEPPELIN_VERSION}.tar.gz

# Allow npm and bower to run with root privileges
# 	Example with doesn't compile all interpreters
#		 mvn -B package -DskipTests -Pbuild-distr -Pspark-3.0 -Pinclude-hadoop -Phadoop3 -Pspark-scala-2.12 -Pweb-angular -pl 's!submarine,!livy,!hbase,!pig,!file,!flink,!ignite,!kylin,!lens' && \
RUN apt-get update \ 
    && mkdir -p ${ZEPPELIN_SOURCE} \
    && wget ${ZEPPELIN_SRC_URL} \
    && tar -xzvf v${ZEPPELIN_VERSION}.tar.gz \
    && echo "unsafe-perm=true" > ~/.npmrc \
    && echo '{ "allow_root": true }' > ~/.bowerrc \
    && cd /zeppelin-${ZEPPELIN_VERSION} \
    && mvn -B package -DskipTests -Pbuild-distr -Pspark-3.0 -Pinclude-hadoop -Phadoop3 -Dhadoop.version=3.2.1 -Pspark-scala-2.12 -Pweb-angular
RUN mv /zeppelin-${ZEPPELIN_VERSION}/zeppelin-distribution/target/zeppelin-*/zeppelin-* /opt/zeppelin/ \
    # Removing stuff saves time, because docker creates a temporary layer
    && rm -rf ~/.m2 \
    && rm -rf /zeppelin-${ZEPPELIN_VERSION}


FROM ubuntu:16.04
MAINTAINER Apache Software Foundation <dev@zeppelin.apache.org>

ENV ZEPPELIN_VERSION="0.10.0-docker"

ENV SPARK_VERSION="3.1.2"

ENV HADOOP_VERSION="3.2.3"
ENV HADOOP_PREFIX=/hadoop-$HADOOP_VERSION
ENV HADOOP_HOME=$HADOOP_PREFIX
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV LD_LIBRARY_PATH=$HADOOP_PREFIX/lib/native
ENV MULTIHOMED_NETWORK=1
ENV PATH $HADOOP_PREFIX/bin/:$PATH
ENV SPARK_DIST_CLASSPATH=$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*


ENV LOG_TAG="[ZEPPELIN_${ZEPPELIN_VERSION}]:" \
    ZEPPELIN_HOME="/zeppelin" \
    SPARK_HOME="/spark" \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    ZEPPELIN_ADDR="0.0.0.0"

RUN echo "$LOG_TAG update and install basic packages" && \
    apt-get -y update && \
    apt-get install -y locales && \
    locale-gen $LANG && \
    apt-get install -y software-properties-common && \
    apt -y autoclean && \
    apt-get install -y gettext-base && \
    apt -y dist-upgrade && \
    apt-get install -y build-essential

RUN echo "$LOG_TAG install tini related packages" && \
    apt-get install -y wget curl grep sed dpkg && \
    TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
RUN echo "$LOG_TAG Install java8" && \
    apt-get -y update && \
    apt-get install -y openjdk-8-jdk && \
    rm -rf /var/lib/apt/lists/*

# install zeppelin
COPY --from=builder /opt/zeppelin ${ZEPPELIN_HOME}

# install spark
RUN curl -s http://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-without-hadoop.tgz | tar -xz -C . \
		&& mv spark-* ${SPARK_HOME}

RUN  wget https://dlcdn.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
      && tar -xvf hadoop-${HADOOP_VERSION}.tar.gz -C . \
      && rm hadoop-${HADOOP_VERSION}.tar.gz
RUN ln -s /$HADOOP_HOME/etc/hadoop /etc/hadoop
RUN mkdir /$HADOOP_HOME/logs

# should install conda first before numpy, matploylib since pip and python will be installed by conda
RUN echo "$LOG_TAG Install miniconda3 related packages" && \
    apt-get -y update && \
    apt-get install -y bzip2 ca-certificates \
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    git mercurial subversion && \
    echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

ENV PATH /opt/conda/bin:$PATH

RUN echo "$LOG_TAG Install python related packages" && \
    apt-get -y update && \
    apt-get install -y python-dev python-pip && \
    apt-get install -y gfortran && \
    # numerical/algebra packages
    apt-get install -y libblas-dev libatlas-dev liblapack-dev && \
    # font, image
    apt-get install -y libpng-dev libfreetype6-dev libxft-dev && \
    # for tkinter
    apt-get install -y python-tk libxml2-dev libxslt-dev zlib1g-dev && \
    hash -r && \
    conda config --set always_yes yes --set changeps1 no && \
    conda update -q conda && \
    conda info -a && \
    conda config --add channels conda-forge
    
RUN echo "$LOG_TAG Cleanup" && \
    apt-get autoclean && \
    apt-get clean

RUN chown -R root:root ${ZEPPELIN_HOME} && \
    mkdir -p ${ZEPPELIN_HOME}/logs ${ZEPPELIN_HOME}/run ${ZEPPELIN_HOME}/webapps && \
    # Allow process to edit /etc/passwd, to create a user entry for zeppelin
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    # Give access to some specific folders
    chmod -R 775 "${ZEPPELIN_HOME}/logs" "${ZEPPELIN_HOME}/run" "${ZEPPELIN_HOME}/notebook" "${ZEPPELIN_HOME}/conf" && \
    # Allow process to create new folders (e.g. webapps)
    chmod 775 ${ZEPPELIN_HOME}


#USER 1000

EXPOSE 8080

COPY log4j.properties ${ZEPPELIN_HOME}/conf/
COPY log4j_docker.properties ${ZEPPELIN_HOME}/conf/

COPY conf.templates ${ZEPPELIN_HOME}/conf.templates

COPY hive-site.xml ${SPARK_HOME}/conf/
COPY spark-env.sh ${SPARK_HOME}/conf/
COPY spark-defaults.conf ${SPARK_HOME}/conf/

WORKDIR ${ZEPPELIN_HOME}

ADD entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

CMD ["bin/zeppelin.sh"]
