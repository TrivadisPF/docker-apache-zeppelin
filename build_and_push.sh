#!/bin/bash

TAG=0.10.1-spark3.2.4-hadoop3.3-java11

docker build -t trivadis/apache-zeppelin:${TAG} .

docker push trivadis/apache-zeppelin:${TAG}