FROM openjdk:8 as builder

WORKDIR /workspace/

RUN git clone https://github.com/apache/zeppelin.git

WORKDIR /workspace/zeppelin

ENV MAVEN_OPTS="-Xms1024M -Xmx2048M -XX:MaxMetaspaceSize=1024m -XX:-UseGCOverheadLimit -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"
# Allow npm and bower to run with root privileges
RUN echo "unsafe-perm=true" > ~/.npmrc && \
    echo '{ "allow_root": true }' > ~/.bowerrc && \
    ./mvnw -B package -DskipTests -Pbuild-distr -Pspark-3.2 -Pinclude-hadoop -Phadoop3 -Pspark-scala-2.12 -Pweb-angular -Pweb-dist && \
    # Example with doesn't compile all interpreters
    # ./mvnw -B package -DskipTests -Pbuild-distr -Pspark-3.2 -Pinclude-hadoop -Phadoop3 -Pspark-scala-2.12 -Pweb-angular -Pweb-dist -pl '!groovy,!submarine,!livy,!hbase,!file,!flink' && \
    mv /workspace/zeppelin/zeppelin-distribution/target/zeppelin-*/zeppelin-* /opt/zeppelin/ && \
    # Removing stuff saves time, because docker creates a temporary layer
    rm -rf ~/.m2 && \
    rm -rf /workspace/zeppelin/*
    
USER root

ENV SPARK_VERSION="3.2.3"
ENV SPARK_HOME="/spark"

ENV HADOOP_VERSION="3.2.3"
ENV HADOOP_HOME=/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV LD_LIBRARY_PATH=$HADOOP_HOME/lib/native
ENV MULTIHOMED_NETWORK=1
ENV PATH $HADOOP_HOME/bin/:$SPARK_HOME/bin:$PATH
ENV SPARK_DIST_CLASSPATH=$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*


# install spark
RUN curl -s https://downloads.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-without-hadoop.tgz | tar -xz -C . \
		&& mv spark-* ${SPARK_HOME}

RUN  wget https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
      && tar -xvf hadoop-${HADOOP_VERSION}.tar.gz -C . \
      && rm hadoop-${HADOOP_VERSION}.tar.gz \
	  && mv hadoop-* / 
RUN ln -s $HADOOP_HOME/etc/hadoop /etc/hadoop
RUN mkdir -p $HADOOP_HOME/logs

RUN mkdir -p /var/log/spark && chmod -R 777 "/var/log/spark"

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
