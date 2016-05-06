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

it_returns_branch_in_metadata() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_commit $repo)

  local dest=$TMPDIR/destination

  get_uri_at_branch $repo branch-a $dest | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
    and
	(.metadata | .[] | select(.name == \"branch\") | .value == $(echo branch-a | jq -R .))
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  rm -rf $dest

  get_uri_at_ref $repo $ref2 $dest | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
    and
	(.metadata | .[] | select(.name == \"branch\") | .value == $(echo $ref2 | jq -R .))
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2
}

it_omits_empty_tags_in_metadata() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)

  local dest=$TMPDIR/destination

  get_uri_at_branch $repo branch-a $dest | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
    and
    ([.metadata | .[] | select(.name == \"tags\")] == [])
  "
}

it_returns_list_of_tags_in_metadata() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)

  git -C $repo tag v1.1-pre
  git -C $repo tag v1.1-final

  local dest=$TMPDIR/destination

  get_uri_at_branch $repo branch-a $dest | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
    and
	(.metadata | .[] | select(.name == \"tags\") | .value == \"v1.1-final,v1.1-pre\")
  "
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

  local dest_all=$TMPDIR/destination_all
  local dest_one=$TMPDIR/destination_one

  get_uri_with_submodules_all \
  "file://"$project_folder 1 $dest_all |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_all/$submodule_name rev-list --all --count)" = 1

  get_uri_with_submodules_at_depth \
  "file://"$project_folder 1 $submodule_name $dest_one |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_one/$submodule_name rev-list --all --count)" = 1
}

it_can_get_and_set_git_config() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  get_uri_with_config $repo $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test "$(git config --global core.pager)" == 'true'
  test "$(git config --global credential.helper)" == '!true long command with variables $@'
}

it_returns_same_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_annotated_tag $repo "1.0-staging" "other tag")
  local ref3=$(make_annotated_tag $repo "0.9-production" "a tag")
  local ref4=$(make_commit $repo)
  local ref5=$(make_annotated_tag $repo "1.1-staging" "another tag")
  local ref6=$(make_commit $repo)

  get_uri_at_ref $repo $ref1 $TMPDIR/destination | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "
  rm -rf $TMPDIR/destination
  get_uri_at_ref $repo $ref2 $TMPDIR/destination | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "
  rm -rf $TMPDIR/destination
  get_uri_at_ref $repo $ref3 $TMPDIR/destination | jq -e "
    .version == {ref: $(echo $ref3 | jq -R .)}
  "
}

run it_can_get_from_url
run it_can_get_from_url_at_ref
run it_can_get_from_url_at_branch
run it_can_get_from_url_only_single_branch
run it_returns_branch_in_metadata
run it_omits_empty_tags_in_metadata
run it_returns_list_of_tags_in_metadata
run it_honors_the_depth_flag
run it_honors_the_depth_flag_for_submodules
run it_can_get_and_set_git_config
run it_returns_same_ref
