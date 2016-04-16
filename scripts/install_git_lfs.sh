#!/bin/sh

set -eu

_main() {
  local tmpdir
  tmpdir="$(mktemp -d git_lfs_install.XXXXXX)"

  cd "$tmpdir"
  curl -Lo git.tar.gz https://github.com/github/git-lfs/releases/download/v1.1.2/git-lfs-linux-amd64-1.1.2.tar.gz
  gunzip git.tar.gz
  tar xf git.tar
  mv git-lfs-1.1.2/git-lfs /usr/bin
  cd ..
  rm -rf "$tmpdir"
  git lfs install --skip-smudge
}

_main "$@"
