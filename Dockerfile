FROM alpine:edge AS tunnelbuilder
RUN apk --no-cache add git make gcc g++ openssl-dev

WORKDIR /root
RUN git clone https://github.com/proxytunnel/proxytunnel.git

WORKDIR /root/proxytunnel
RUN make

FROM alpine:edge AS resource

RUN apk --no-cache add \
  bash \
  curl \
  git \
  git-daemon \
  gnupg \
  gzip \
  jq \
  openssh \
  perl \
  tar \
  openssl \
  libstdc++

COPY --from=tunnelbuilder /root/proxytunnel/proxytunnel proxytunnel

RUN /usr/bin/install -c proxytunnel /usr/bin/proxytunnel

RUN git config --global user.email "git@localhost"
RUN git config --global user.name "git"

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

ADD scripts/install_git_lfs.sh install_git_lfs.sh
RUN ./install_git_lfs.sh && rm ./install_git_lfs.sh

ADD scripts/install_git_crypt.sh install_git_crypt.sh
RUN ./install_git_crypt.sh && rm ./install_git_crypt.sh

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
                    git-shell \
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
                    git \
                    git-cvsserver \
                    git-shell \
                    git-receive-pack \
                    git-upload-pack \
                    git-upload-archive &&\
                ln -s ../libexec/git-core/git git &&\
                ln -s ../libexec/git-core/git-shell git-shell &&\
                ln -s ../libexec/git-core/git git-upload-archive &&\
                ln -s ../libexec/git-core/git-upload-pack git-upload-pack

WORKDIR         /usr/libexec/git-core
RUN             ln -s git git-merge

WORKDIR         /usr/share
RUN             rm -rf \
                    gitweb \
                    locale \
                    perl \
                    perl5

WORKDIR         /usr/lib
RUN             rm -rf \
                    perl \
                    perl5

FROM resource AS tests
ADD test/ /tests
RUN /tests/all.sh

FROM resource AS integrationtests
RUN apk --no-cache add squid
ADD test/ /tests/test
ADD integration-tests /tests/integration-tests
RUN /tests/integration-tests/integration.sh

FROM resource
