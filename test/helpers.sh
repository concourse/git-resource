#!/bin/sh

set -e

set -o pipefail

resource_dir=/opt/resource

cleanup() {
  if [ -n "$DEBUG" ]; then
    echo $1
  else
    rm -rf $1
  fi
}

run() {
  export TMPDIR=$(mktemp -d /tmp/git-tests.XXXXXX)
  trap "cleanup $TMPDIR" EXIT

  echo -e 'running \e[33m'"$@"$'\e[0m...'
  eval "$@" 2>&1 | sed -e 's/^/  /g'
  echo ""
}

init_repo() {
  (
    set -e
    cd $(mktemp -d $TMPDIR/repo.XXXXXX)
    git init -q
    pwd
  )
}

make_commit_to() {
  echo x >> $2/$1
  git -C $2 add $1
  git -C $2 -c user.name='test' -c user.email='test@example.com' commit -q -m "commit $(wc -l $2/$1)"
  git -C $2 rev-parse HEAD
}

make_commit() {
  make_commit_to some-file $1
}

check_uri() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_ignoring() {
  local uri=$1

  shift

  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      ignore_paths: $(echo "$@" | jq -R '. | split(" ")')
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_paths() {
  local uri=$1

  shift

  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      paths: $(echo "$@" | jq -R '. | split(" ")')
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_paths_ignoring() {
  local uri=$1
  local paths=$2

  shift 2

  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      paths: [$(echo $paths | jq -R .)],
      ignore_paths: $(echo "$@" | jq -R '. | split(" ")')
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_from() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    version: {
      ref: $(echo $2 | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_from_ignoring() {
  local uri=$1
  local ref=$2

  shift 2

  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      ignore_paths: $(echo "$@" | jq -R '. | split(" ")')
    },
    version: {
      ref: $(echo $ref | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_from_paths() {
  local uri=$1
  local ref=$2

  shift 2

  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      paths: $(echo "$@" | jq -R '. | split(" ")')
    },
    version: {
      ref: $(echo $ref | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_from_paths_ignoring() {
  local uri=$1
  local ref=$2
  local paths=$3

  shift 3

  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      paths: [$(echo $paths | jq -R .)],
      ignore_paths: $(echo "$@" | jq -R '. | split(" ")')
    },
    version: {
      ref: $(echo $ref | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}
