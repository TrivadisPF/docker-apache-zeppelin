FROM apache/zeppelin:0.10.0
MAINTAINER Apache Software Foundation <dev@zeppelin.apache.org>

USER root

ENV ZEPPELIN_VERSION="0.10.0"

ENV SPARK_VERSION="3.1.3"
ENV HADOOP_VERSION=3.2.3
ENV SPARK_HOME="/spark-3.2.3"

ARG SPARK_BUILD_NAME='without-hadoop'
ARG SPARK_BUILD_PROFILES='-Phive -Phive-thriftserver -Pyarn -Phadoop-provided -Dhadoop.version=3.2.3'

ARG SPARK_SRC_URL=https://github.com/apache/spark/archive/refs/tags/v${SPARK_VERSION}.tar.gz

RUN wget ${SPARK_SRC_URL} \
    && tar -xf v${SPARK_VERSION}.tar.gz \
    && rm v${SPARK_VERSION}.tar.gz \
    && cd spark-${SPARK_VERSION} \
    && ./dev/make-distribution.sh --name ${SPARK_BUILD_NAME} --tgz ${SPARK_BUILD_PROFILES}

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
