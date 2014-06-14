FROM ubuntu:14.04

RUN apt-get update && apt-get -y install git

ADD http://stedolan.github.io/jq/download/linux64/jq /usr/local/bin/jq
RUN chmod +x /usr/local/bin/jq

ADD assets/ /tmp/resource/
RUN chmod +x /tmp/resource/*
