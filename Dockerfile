ARG base_image=cgr.dev/chainguard/wolfi-base:latest

FROM ${base_image} AS proxytunnel
RUN apk --no-cache add \
    git \
    make \
    gcc \
    openssl-dev

WORKDIR /root
RUN git clone https://github.com/proxytunnel/proxytunnel.git && \
    cd proxytunnel && \
    make -j4

FROM ${base_image} AS resource
COPY --from=proxytunnel /root/proxytunnel/proxytunnel /usr/bin/

# minimum dependencies we need for the resource
RUN apk --no-cache add \
    bash \
    ca-certificates \
    coreutils \
    git \
    git-crypt \
    git-lfs \
    gnupg \
    gnupg-dirmngr \
    gpg \
    gpg-agent \
    jq \
    openssh-client \
    openssl \
    curl

RUN git config --global user.email "git@localhost"
RUN git config --global user.name "git"
RUN git config --global pull.rebase "false"
RUN git config --global protocol.file.allow "always"
RUN git config --global http.version "HTTP/2"

# Remove unrelated git binaries we don't need
WORKDIR /usr/libexec/git-core
RUN rm -f \
    git-archimport \
    git-cvsexportcommit \
    git-cvsimport \
    git-cvsserver \
    git-svn \
    git-web--browse

WORKDIR /usr/bin
RUN rm -f git-cvsserver

WORKDIR /usr/share
RUN rm -rf locale

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

FROM resource AS tests
RUN apk --no-cache add cmd:ssh-keygen
ADD test/ /tests
RUN /tests/all.sh

FROM resource AS integrationtests
RUN apk --no-cache add iproute2 squid
ADD test/ /tests/test
ADD integration-tests /tests/integration-tests
RUN /tests/integration-tests/integration.sh

FROM resource
