#!/bin/sh

set -eu

_main() {
  local tmpdir
  tmpdir="$(mktemp -d git_crypt_install.XXXXXX)"

  cd "$tmpdir"
  git clone https://github.com/AGWA/git-crypt.git
  cd git-crypt
  git checkout tags/0.6.0
  make
  make install
  cd ../..
  rm -rf "$tmpdir"
}

_main "$@"
