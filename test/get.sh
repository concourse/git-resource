#!/bin/sh

set -e

source $(dirname $0)/helpers.sh

it_can_get_from_url() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  get_uri $repo $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref
}

it_can_get_from_url_at_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)

  local dest=$TMPDIR/destination

  get_uri_at_ref $repo $ref1 $dest | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  rm -rf $dest

  get_uri_at_ref $repo $ref2 $dest | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2
}

it_can_get_from_url_at_branch() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_commit_to_branch $repo branch-b)

  local dest=$TMPDIR/destination

  get_uri_at_branch $repo "branch-a" $dest | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  rm -rf $dest

  get_uri_at_branch $repo "branch-b" $dest | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2
}

it_can_get_from_url_only_single_branch() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  get_uri $repo $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  ! git -C $dest rev-parse origin/bogus
}

it_honors_the_depth_flag() {
  local repo=$(init_repo)
  local firstCommitRef=$(make_commit $repo)

  make_commit $repo

  local lastCommitRef=$(make_commit $repo)

  local dest=$TMPDIR/destination

  get_uri_at_depth "file://"$repo 1 $dest |  jq -e "
    .version == {ref: $(echo $lastCommitRef | jq -R .)}
  "

  test "$(git -C $dest rev-parse HEAD)" = $lastCommitRef
  test "$(git -C $dest rev-list --all --count)" = 1
}

it_honors_the_depth_flag_for_submodules() {
  local repo_with_submodule_info=$(init_repo_with_submodule)
  local project_folder=$(echo $repo_with_submodule_info | cut -d "," -f1)
  local submodule_folder=$(echo $repo_with_submodule_info | cut -d "," -f2)
  local submodule_name=$(basename $submodule_folder)
  local project_last_commit_id=$(git -C $project_folder rev-parse HEAD)

  local dest=$TMPDIR/destination

  get_uri_with_submodules_at_depth "file://"$project_folder 1 $dest |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest/$submodule_name rev-list --all --count)" = 1
}

run it_can_get_from_url
run it_can_get_from_url_at_ref
run it_can_get_from_url_at_branch
run it_can_get_from_url_only_single_branch
run it_honors_the_depth_flag
run it_honors_the_depth_flag_for_submodules