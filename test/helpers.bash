#!/bin/bash

set -e -x

set -o pipefail

resource_dir=$(cd $(dirname $0)/.. && pwd)
assets_dir=${resource_dir}/assets

function cleanup() {
  cd $resource_dir

  if [ -n "$DEBUG" ]; then
    echo $1
  else
    rm -rf $1
  fi
}

function with_tmpdir() {
  export TMPDIR=$(mktemp -d /tmp/git-tests.XXXXXX)
  trap "cleanup $TMPDIR" EXIT

  eval "$@"
}

function check_uri() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    }
  }" | ${assets_dir}/check | tee /dev/stderr
}

function check_uri_ref() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    version: {
      ref: $(echo $2 | jq -R .)
    }
  }" | ${assets_dir}/check | tee /dev/stderr
}

function init_repo() {
  (
    set -e
    cd $(mktemp -d $TMPDIR/repo.XXXXX)
    git init -q
    pwd
  )
}

function make_commit() {
  echo x >> $1/some-file
  git -C $1 add some-file
  git -C $1 commit -q -m "commit $(wc -l $1/some-file)"
  git -C $1 rev-parse HEAD
}
