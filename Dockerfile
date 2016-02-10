FROM concourse/busyboxplus:git

ENV LANG C

ADD http://stedolan.github.io/jq/download/linux64/jq /usr/local/bin/jq
RUN chmod +x /usr/local/bin/jq

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

ADD scripts/install_git_lfs.sh install_git_lfs.sh
RUN ./install_git_lfs.sh

ADD test/ /opt/resource-tests/
RUN /opt/resource-tests/all.sh && \
  rm -rf /tmp/*
