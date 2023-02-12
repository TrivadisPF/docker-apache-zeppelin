FROM openjdk:8 AS sparkbuild

ENV SPARK_VERSION=3.2.3
ENV HADOOP_VERSION=3.2.4

ARG SPARK_BUILD_NAME='without-hadoop'
ARG SPARK_BUILD_PROFILES='-Phive -Phive-thriftserver -Pyarn -Phadoop-provided -Dhadoop.version=3.2.4'

ARG SPARK_SRC_URL=https://github.com/apache/spark/archive/refs/tags/v${SPARK_VERSION}.tar.gz

RUN wget ${SPARK_SRC_URL} \
    && tar -xf v${SPARK_VERSION}.tar.gz \
    && rm v${SPARK_VERSION}.tar.gz \
    && cd spark-${SPARK_VERSION} \
    && ./dev/make-distribution.sh --name ${SPARK_BUILD_NAME} --tgz ${SPARK_BUILD_PROFILES}


FROM apache/zeppelin:0.10.1

USER root

ENV ZEPPELIN_VERSION="0.10.1"

ENV SPARK_VERSION="3.2.3"
ENV HADOOP_VERSION=3.2.4
ENV HIVE_VERSION=2.3.7

ENV SPARK_SOURCE=spark-${SPARK_VERSION}
ENV ENABLE_INIT_DAEMON true
ENV INIT_DAEMON_BASE_URI http://identifier/init-daemon
ENV INIT_DAEMON_STEP spark_master_init

COPY --from=sparkbuild ${SPARK_SOURCE}/spark-${SPARK_VERSION}-bin-without-hadoop.tgz .

# Setup Perl so that entrypoint.sh works
#RUN apk add --update perl && rm -rf /var/cache/apk/*

RUN  wget https://www.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
      && tar -xvf hadoop-${HADOOP_VERSION}.tar.gz -C /opt/ \
      && rm hadoop-${HADOOP_VERSION}.tar.gz \
      && cd /

RUN ln -s /opt/hadoop-$HADOOP_VERSION/etc/hadoop /etc/hadoop

RUN mkdir /opt/hadoop-$HADOOP_VERSION/logs

RUN mkdir /hadoop-data

ENV HADOOP_PREFIX=/opt/hadoop-$HADOOP_VERSION
ENV HADOOP_HOME=$HADOOP_PREFIX
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV LD_LIBRARY_PATH=$HADOOP_PREFIX/lib/native
ENV MULTIHOMED_NETWORK=1
ENV USER=root
ENV PATH $HADOOP_PREFIX/bin/:$PATH
ENV SPARK_DIST_CLASSPATH=$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*

RUN apt-get -y update \ 
      && apt-get install -y curl bash gnupg wget procps coreutils \
      && rm -rf /var/lib/apt/lists/*  \
      && apt-get autoclean \
      && apt-get clean \
      && ln -s /lib64/ld-linux-x86-64.so.2 /lib/ld-linux-x86-64.so.2 \
#      && chmod +x *.sh \
      && tar -xvzf spark-${SPARK_VERSION}-bin-without-hadoop.tgz \
      && mv spark-${SPARK_VERSION}-bin-without-hadoop /spark \
      && rm spark-${SPARK_VERSION}-bin-without-hadoop.tgz \
      && wget https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz \
	  && tar -xzvf apache-hive-$HIVE_VERSION-bin.tar.gz \
	  && mv apache-hive-$HIVE_VERSION-bin /hive \
	  && rm apache-hive-$HIVE_VERSION-bin.tar.gz \
      && cd /
      
      
RUN mkdir -p /var/log/spark && chmod -R 777 "/var/log/spark"

ENV SPARK_HOME=/spark
ENV PATH /spark/bin:$PATH

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

#USER 1000

CMD ["bin/zeppelin.sh"]
