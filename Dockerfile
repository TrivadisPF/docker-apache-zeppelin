FROM trivadis/apache-spark-base:3.0.1-hadoop3.2

MAINTAINER Guido Schmutz <guido.schmutz@trivadis.com>

ENV ZEPPELIN_VERSION 0.8.2
ENV HADOOP_VERSION 3.2.1


RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh	gettext

RUN set -x \
    && curl -fSL "http://www-eu.apache.org/dist/zeppelin/zeppelin-${ZEPPELIN_VERSION}/zeppelin-${ZEPPELIN_VERSION}-bin-all.tgz" -o /tmp/zeppelin.tgz \
    && mkdir -p /opt \
    && tar -xzvf /tmp/zeppelin.tgz -C /opt/ \
    && mv /opt/zeppelin-* /opt/zeppelin \
    && rm /tmp/zeppelin.tgz

# install s3cmd and awscli
RUN pip install --upgrade pip awscli s3cmd && \
    mkdir /root/.aws

# install hadoop client
RUN curl -O https://dist.apache.org/repos/dist/release/hadoop/common/KEYS

RUN gpg --import KEYS

ENV HADOOP_URL https://www.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz

RUN set -x \
    && curl -fSL "$HADOOP_URL" -o /tmp/hadoop.tar.gz \
    && curl -fSL "$HADOOP_URL.asc" -o /tmp/hadoop.tar.gz.asc \
    && gpg --verify /tmp/hadoop.tar.gz.asc \
    && tar -xvf /tmp/hadoop.tar.gz -C /opt/ \
    && rm /tmp/hadoop.tar.gz*

RUN ln -s /opt/hadoop-$HADOOP_VERSION/etc/hadoop /etc/hadoop

ENV HADOOP_PREFIX=/opt/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV MULTIHOMED_NETWORK=1
ENV USER=root
ENV PATH $HADOOP_PREFIX/bin/:$PATH

# ENV SPARK_SUBMIT_OPTIONS "--jars /opt/zeppelin/sansa-examples-spark-2018-06.jar"
ENV SPARK_HOME /spark

WORKDIR /opt/zeppelin

ADD entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

CMD ["/opt/zeppelin/bin/zeppelin.sh"]
