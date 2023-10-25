ARG base_image

FROM ${base_image} AS resource
USER root

RUN apt update && apt upgrade -y -o Dpkg::Options::="--force-confdef"
RUN apt install -y --no-install-recommends \
    curl \
    git \
    git-lfs \
    gnupg \
    gzip \
    jq \
    openssl \
    libssl-dev \
    make \
    g++ \
    openssh-client \
    libstdc++6 \
    software-properties-common \
    wget \
    ca-certificates \
    vim

# From : https://github.com/totegamma/githubapps-content-resource/blob/master/Dockerfile
RUN wget https://github.com/mike-engel/jwt-cli/releases/download/5.0.3/jwt-linux.tar.gz \
 && tar -zxvf jwt-linux.tar.gz \
 && mv jwt /usr/local/bin

WORKDIR /root
RUN git clone https://github.com/proxytunnel/proxytunnel.git && \
    cd proxytunnel && \
    make -j4 && \
    install -c proxytunnel /usr/bin/proxytunnel && \
    cd .. && \
    rm -rf proxytunnel

RUN git config --global user.email "git@localhost"
RUN git config --global user.name "git"
RUN git config --global pull.rebase "false"
RUN git config --global protocol.file.allow "always"


ENV CXXFLAGS -DOPENSSL_API_COMPAT=0x30000000L
ADD scripts/install_git_crypt.sh install_git_crypt.sh
RUN ./install_git_crypt.sh && rm ./install_git_crypt.sh
ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

WORKDIR         /usr/libexec/git-core
RUN             rm -f \
                    git-add \
                    git-add--interactive \
                    git-annotate \
                    git-apply \
                    git-archimport \
                    git-archive \
                    git-bisect--helper \
                    git-blame \
                    git-branch \
                    git-bundle \
                    git-credential-cache \
                    git-credential-cache--daemon \
                    git-credential-store \
                    git-cat-file \
                    git-check-attr \
                    git-check-ignore \
                    git-check-mailmap \
                    git-check-ref-format \
                    git-checkout \
                    git-checkout-index \
                    git-cherry \
                    git-cherry-pick \
                    git-clean \
                    git-clone \
                    git-column \
                    git-commit \
                    git-commit-tree \
                    git-config \
                    git-count-objects \
                    git-credential \
                    git-cvsexportcommit \
                    git-cvsimport \
                    git-cvsserver \
                    git-describe \
                    git-diff \
                    git-diff-files \
                    git-diff-index \
                    git-diff-tree \
                    git-difftool \
                    git-fast-export \
                    git-fast-import \
                    git-fetch \
                    git-fetch-pack \
                    git-fmt-merge-msg \
                    git-for-each-ref \
                    git-format-patch \
                    git-fsck \
                    git-fsck-objects \
                    git-gc \
                    git-get-tar-commit-id \
                    git-grep \
                    git-hash-object \
                    git-help \
                    git-http-backend\
                    git-imap-send \
                    git-index-pack \
                    git-init \
                    git-init-db \
                    git-lfs \
                    git-log \
                    git-ls-files \
                    git-ls-remote \
                    git-ls-tree \
                    git-mailinfo \
                    git-mailsplit \
                    git-merge \
                    git-mktag \
                    git-mktree \
                    git-mv \
                    git-name-rev \
                    git-notes \
                    git-p4 \
                    git-pack-objects \
                    git-pack-redundant \
                    git-pack-refs \
                    git-patch-id \
                    git-peek-remote \
                    git-prune \
                    git-prune-packed \
                    git-push \
                    git-read-tree \
                    git-reflog \
                    git-relink \
                    git-remote \
                    git-remote-ext \
                    git-remote-fd \
                    git-remote-testsvn \
                    git-repack \
                    git-replace \
                    git-repo-config \
                    git-rerere \
                    git-reset \
                    git-rev-list \
                    git-rev-parse \
                    git-revert \
                    git-rm \
                    git-send-email \
                    git-send-pack \
                    git-shortlog \
                    git-show \
                    git-show-branch \
                    git-show-index \
                    git-show-ref \
                    git-stage \
                    git-show-ref \
                    git-stage \
                    git-status \
                    git-stripspace \
                    git-svn \
                    git-symbolic-ref \
                    git-tag \
                    git-tar-tree \
                    git-unpack-file \
                    git-unpack-objects \
                    git-update-index \
                    git-update-ref \
                    git-update-server-info \
                    git-upload-archive \
                    git-var \
                    git-verify-pack \
                    git-verify-tag \
                    git-whatchanged \
                    git-write-tree

WORKDIR         /usr/bin
RUN             rm -f \
                    git-cvsserver \
                    git-shell \
                    git-receive-pack \
                    git-upload-pack \
                    git-upload-archive &&\
                ln -s git git-upload-archive &&\
                ln -s git git-merge &&\
                ln -s git git-crypt

WORKDIR         /usr/share
RUN             rm -rf \
                    gitweb \
                    locale \
                    perl

WORKDIR         /usr/lib
RUN             rm -rf \
                    perl

FROM resource AS tests
ADD test/ /tests
RUN /tests/all.sh

FROM resource AS integrationtests
RUN apt update && apt install -y squid
ADD test/ /tests/test
ADD integration-tests /tests/integration-tests
RUN /tests/integration-tests/integration.sh

FROM resource
