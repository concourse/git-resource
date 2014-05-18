FROM ubuntu:14.04

RUN apt-get -y install git

ADD http://stedolan.github.io/jq/download/linux64/jq /usr/local/bin/jq
RUN chmod +x /usr/local/bin/jq

ADD assets/in /tmp/resource/in
RUN chmod +x /tmp/resource/in

ADD assets/check /tmp/resource/check
RUN chmod +x /tmp/resource/check
