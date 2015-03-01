FROM concourse/busyboxplus:git

ADD http://stedolan.github.io/jq/download/linux64/jq /usr/local/bin/jq
RUN chmod +x /usr/local/bin/jq

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

# this seems to end up in the busybox image as a symlink to /tmp/resolv.conf,
# which confuses things
RUN rm /etc/resolv.conf
