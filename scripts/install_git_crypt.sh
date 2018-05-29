#!/bin/sh

set -eu

_main() {
  local tmpdir
  tmpdir="$(mktemp -d git_crypt_install.XXXXXX)"

  cd "$tmpdir"
  apk --no-cache add ca-certificates
  wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-git-crypt/master/sgerrand.rsa.pub
  wget https://github.com/sgerrand/alpine-pkg-git-crypt/releases/download/0.6.0-r0/git-crypt-0.6.0-r0.apk
  apk add git-crypt-0.6.0-r0.apk
  cd ..
  rm -rf "$tmpdir"
}

_main "$@"
