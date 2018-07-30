#!/bin/sh

set -eu

_main() {
  local tmpdir
  tmpdir="$(mktemp -d git_crypt_install.XXXXXX)"

  cd "$tmpdir"
  curl -Lo git-crypt-0.6.0.tar.gz https://www.agwa.name/projects/git-crypt/downloads/git-crypt-0.6.0.tar.gz
  tar -zxf git-crypt-0.6.0.tar.gz
  cd git-crypt-0.6.0
  make
  make install
  cd ..
  rm -rf "$tmpdir"
}

_main "$@"
