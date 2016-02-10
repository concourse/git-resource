#!/bin/sh

set -e

. "$(dirname "$0")/helpers.sh"

it_has_installed_git_lfs() {
  git lfs env
}

it_cleans_up_installation_artifacts() {
  test ! -d git_lfs_install*
}

run it_has_installed_git_lfs
run it_cleans_up_installation_artifacts
