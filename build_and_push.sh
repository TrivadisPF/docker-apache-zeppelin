#!/bin/bash

TAG=0.10.1-spark3.3.2-hadoop3.3-java17

docker build -t trivadis/apache-zeppelin:${TAG} .

docker push trivadis/apache-zeppelin:${TAG}