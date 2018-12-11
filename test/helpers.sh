#!/bin/bash

set -e -u

set -o pipefail

export TMPDIR_ROOT=$(mktemp -d /tmp/git-tests.XXXXXX)
trap "rm -rf $TMPDIR_ROOT" EXIT

if [ -d /opt/resource ]; then
  resource_dir=/opt/resource
else
  resource_dir=$(cd $(dirname $0)/../assets && pwd)
fi
test_dir=$(cd $(dirname $0) && pwd)
keygrip=276D99F5B65388AF85DF54B16B08EF0A44C617AC
fingerprint=A3E20CD6371D49E244B0730D1CDD25AEB0F5F8EF

run() {
  export TMPDIR=$(mktemp -d ${TMPDIR_ROOT}/git-tests.XXXXXX)

  echo -e 'running \e[33m'"$@"$'\e[0m...'
  eval "$@" 2>&1 | sed -e 's/^/  /g'
  echo ""
}

init_repo() {
  (
    set -e

    cd $(mktemp -d $TMPDIR/repo.XXXXXX)

    git init -q

    # start with an initial commit
    git \
      -c user.name='test' \
      -c user.email='test@example.com' \
      commit -q --allow-empty -m "init"

    # create some bogus branch
    git checkout -b bogus

    git \
      -c user.name='test' \
      -c user.email='test@example.com' \
      commit -q --allow-empty -m "commit on other branch"

    # back to master
    git checkout master

    # print resulting repo
    pwd
  )
}

init_repo_with_submodule() {
  local submodule=$(init_repo)
  make_commit $submodule >/dev/null
  make_commit $submodule >/dev/null

  local project=$(init_repo)
  git -C $project submodule add "file://$submodule" >/dev/null
  git -C $project commit -m "Adding Submodule" >/dev/null
  echo $project,$submodule
}

init_repo_with_submodule_of_nested_submodule() {
  local submodule_and_nested_submodule=$(init_repo_with_submodule)
  local nested_submodule=$(echo $submodule_and_nested_submodule | cut -d "," -f2)
  local submodule=$(echo $submodule_and_nested_submodule | cut -d "," -f1)
  make_commit $submodule >/dev/null
  make_commit $submodule >/dev/null

  local project=$(init_repo)
  git -C $project submodule add "file://$submodule" >/dev/null
  git -C $project commit -m "Adding Submodule" >/dev/null
  echo $project,$submodule,$nested_submodule
}

fetch_head_ref() {
  local repo=$1

  git -C $repo rev-parse HEAD
}

make_commit_to_file_on_branch() {
  local repo=$1
  local file=$2
  local branch=$3
  local msg=${4-}

  # ensure branch exists
  if ! git -C $repo rev-parse --verify $branch >/dev/null; then
    git -C $repo branch $branch master
  fi

  # switch to branch
  git -C $repo checkout -q $branch

  # modify file and commit
  echo x >> $repo/$file
  git -C $repo add $file
  git -C $repo \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -q -m "commit $(wc -l $repo/$file) $msg"

  # output resulting sha
  git -C $repo rev-parse HEAD
}

make_commit_to_file() {
  make_commit_to_file_on_branch $1 $2 master "${3-}"
}

make_commit_to_branch() {
  make_commit_to_file_on_branch $1 some-file $2
}

make_commit() {
  make_commit_to_file $1 some-file "${2:-}"
}

make_commit_to_be_skipped() {
  make_commit_to_file $1 some-file "[ci skip]"
}

make_commit_to_be_skipped2() {
  make_commit_to_file $1 some-file "[skip ci]"
}


merge_branch() {
  local repo=$1
  local target=$2
  local branch=$3

  # switch to branch
  git -C $repo checkout -q $target

  # merge in branch
  git -C $repo merge -q --no-ff $branch

  # output resulting sha
  git -C $repo rev-parse HEAD
}

delete_public_key() {
  if gpg -k ${fingerprint} > /dev/null; then
    gpg --batch --yes --delete-keys ${fingerprint}
  fi
}

gpg_fixture_repo_path() {
  echo "${test_dir}/gpg/fixture_repo.git"
}

git_crypt_fixture_repo_path() {
  echo "${test_dir}/git-crypt/fixture_repo.git"
}

git_crypt_fixture_key_path() {
  echo "${test_dir}/git-crypt/fixture_repo.key"
}

make_empty_commit() {
  local repo=$1
  local msg=${2-}

  git -C $repo \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -q --allow-empty -m "commit $msg"

  # output resulting sha
  git -C $repo rev-parse HEAD
}

make_annotated_tag() {
  local repo=$1
  local tag=$2
  local msg=$3

  git -C $repo tag -f -a "$tag" -m "$msg"

  git -C $repo describe --tags --abbrev=0
}

check_uri() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_with_branch() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: $(echo $2 | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

get_initial_ref() {
  local repo=$1

  git -C $repo rev-list HEAD | tail -n 1
}

check_uri_with_key() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      private_key: $(cat $2 | jq -s -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_with_credentials() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      username: $(echo $2 | jq -R .),
      password: $(echo $3 | jq -R .)
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

check_uri_with_tag_filter() {
  local uri=$1
  local tag_filter=$2
  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      tag_filter: $(echo $tag_filter | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_with_tag_filter_given_branch() {
  local uri=$1
  local tag_filter=$2
  local branch=$3
  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      tag_filter: $(echo $tag_filter | jq -R .),
      branch: $(echo $branch | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_with_tag_filter_from() {
  local uri=$1
  local tag_filter=$2
  local ref=$3

  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      tag_filter: $(echo $tag_filter | jq -R .)
    },
    version: {
      ref: $(echo $ref | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_with_config() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      git_config: [
        {
          name: \"core.pager\",
          value: \"true\"
        },
        {
          name: \"credential.helper\",
          value: \"!true long command with variables \$@\"
        }
      ]
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_disable_ci_skip() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      disable_ci_skip: true
    },
    version: {
      ref: $(echo $2 | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

get_uri() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
    },
    params: {
      short_ref_format: \"test-%s\"
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
}

get_uri_with_branch() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: $(echo $2 | jq -R .),
    },
    params: {
      short_ref_format: \"test-%s\"
    }
  }" | ${resource_dir}/in "$3" | tee /dev/stderr
}

get_uri_with_git_crypt_key() {
  local git_crypt_key_path=$(git_crypt_fixture_key_path)
  local git_crypt_key_base64_encoded=$(cat $git_crypt_key_path | base64)

  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      git_crypt_key: $(echo $git_crypt_key_base64_encoded | jq -R .)
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
}

get_uri_at_depth() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    params: {
      depth: $(echo $2 | jq -R .)
    }
  }" | ${resource_dir}/in "$3" | tee /dev/stderr
}

get_uri_at_depth_at_ref() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    params: {
      depth: $(echo $2 | jq -R .)
    },
    version: {
      ref: $(echo $3 | jq -R .)
    }
  }" | ${resource_dir}/in "$4" | tee -a /dev/stderr
}

get_uri_with_submodules_at_depth() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    params: {
      depth: $(echo $2 | jq -R .),
      submodules: [$(echo $3 | jq -R .)],
    }
  }" | ${resource_dir}/in "$4" | tee /dev/stderr
}

get_uri_with_submodules_all() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    params: {
      depth: $(echo $2 | jq -R .),
      submodules: \"all\",
    }
  }" | ${resource_dir}/in "$3" | tee /dev/stderr
}

get_uri_with_submodules_and_parameter_remote() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    params: {
      depth: $(echo $2 | jq -R .),
      submodules: $(echo $3 | jq -R .),
      submodule_remote: $(echo $4 | jq -R .),
    }
  }" | ${resource_dir}/in "$5" | tee /dev/stderr
}

get_uri_with_submodules_and_parameter_recursive() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    params: {
      depth: $(echo $2 | jq -R .),
      submodules: $(echo $3 | jq -R .),
      submodule_recursive: $(echo $4 | jq -R .),
    }
  }" | ${resource_dir}/in "$5" | tee /dev/stderr
}

get_uri_at_ref() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    version: {
      ref: $(echo $2 | jq -R .)
    },
    params: {
      short_ref_format: \"test-%s\"
    }
  }" | ${resource_dir}/in "$3" | tee /dev/stderr
}

get_uri_at_branch() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: $(echo $2 | jq -R .)
    }
  }" | ${resource_dir}/in "$3" | tee /dev/stderr
}

get_uri_with_config() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      git_config: [
        {
          name: \"core.pager\",
          value: \"true\"
        },
        {
          name: \"credential.helper\",
          value: \"!true long command with variables \$@\"
        }
      ]
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
}

get_uri_with_verification_key() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      commit_verification_keys: [\"$(cat ${test_dir}/gpg/public.key)\"]
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
  exit_code=$?
  delete_public_key
  return ${exit_code}
}

get_uri_with_verification_key_and_tag_filter() {
  local uri=$1
  local dest=$2
  local tag_filter=$3
  local version=$4
  jq -n "{
    source: {
      uri: $(echo $uri | jq -R .),
      commit_verification_keys: [\"$(cat ${test_dir}/gpg/public.key)\"],
      tag_filter: $(echo $tag_filter | jq -R .)
    },
    version: {
      ref: $(echo $version | jq -R .)
    }
  }" | ${resource_dir}/in "$dest" | tee /dev/stderr
  exit_code=$?
  delete_public_key
  return ${exit_code}
}

get_uri_with_invalid_verification_key() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      commit_verification_keys: [\"abcd\"]
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
}

get_uri_with_unknown_verification_key() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      commit_verification_keys: [\"$(cat ${test_dir}/gpg/unknown_public.key)\"]
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
  exit_code=$?
  delete_public_key
  return ${exit_code}
}

get_uri_when_using_keyserver() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      commit_verification_key_ids: [\"A3E20CD6371D49E244B0730D1CDD25AEB0F5F8EF\"]
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
  exit_code=$?
  delete_public_key
  return ${exit_code}
}

get_uri_when_using_keyserver_and_bogus_key() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      commit_verification_key_ids: [\"abcd\"]
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
}

get_uri_when_using_keyserver_and_unknown_key() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      commit_verification_key_ids: [\"24C51CCE1AB7B2EFEF72B9A48EAB0B8DEE26E5FD\"]
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
}

get_uri_with_clean_tags() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    params: {
      clean_tags: $(echo $3 | jq -R .),
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
}

put_uri() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_force() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .),
      force: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_only_tag() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .),
      only_tag: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_only_tag_with_force() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .),
      only_tag: true,
      force: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_rebase() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .),
      rebase: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_merge() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .),
      merge: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_merge_and_rebase() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .),
      merge: true,
      rebase: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_tag() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      repository: $(echo $4 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_tag_and_prefix() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      tag_prefix: $(echo $4 | jq -R .),
      repository: $(echo $5 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_tag_and_annotation() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      annotate: $(echo $4 | jq -R .),
      repository: $(echo $5 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_rebase_with_tag() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      repository: $(echo $4 | jq -R .),
      rebase: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_rebase_with_tag_and_prefix() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      tag_prefix: $(echo $4 | jq -R .),
      repository: $(echo $5 | jq -R .),
      rebase: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_notes() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      notes: $(echo $3 | jq -R .),
      repository: $(echo $4 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_rebase_with_notes() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      notes: $(echo $3 | jq -R .),
      repository: $(echo $4 | jq -R .),
      rebase: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_config() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\",
      git_config: [
        {
          name: \"core.pager\",
          value: \"true\"
        },
        {
          name: \"credential.helper\",
          value: \"!true long command with variables \$@\"
        }
      ]
    },
    params: {
      repository: $(echo $3 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}
