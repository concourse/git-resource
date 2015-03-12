FROM concourse/busyboxplus:git

ENV LANG C

ADD http://stedolan.github.io/jq/download/linux64/jq /usr/local/bin/jq
RUN chmod +x /usr/local/bin/jq

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*
