#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

it_can_put_to_url() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  # create a tag to push
  git -C $repo2 tag some-tag

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri $repo1 $src repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $ref
  test "$(git -C $repo1 rev-parse some-tag)" = $ref
}

it_returns_branch_in_metadata() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  # create a tag to push
  git -C $repo2 tag some-tag

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri $repo1 $src repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
    and
	(.metadata | .[] | select(.name == \"branch\") | .value == $(echo master | jq -R .))
  "
}

it_can_put_to_url_with_tag() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  echo some-tag-name > $src/some-tag-file

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_tag $repo1 $src some-tag-file repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $ref
  test "$(git -C $repo1 rev-parse some-tag-name)" = $ref
}

it_can_put_to_url_with_tag_and_prefix() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  echo 1.0 > $src/some-tag-file

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_tag_and_prefix $repo1 $src some-tag-file v repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $ref
  test "$(git -C $repo1 rev-parse v1.0)" = $ref
}

it_can_put_to_url_with_tag_and_annotation() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  echo 1.0 > $src/some-tag-file
  echo yay > $src/some-annotation-file

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_tag_and_annotation $repo1 $src "$src/some-tag-file" "$src/some-annotation-file" repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file

  # Annotated tags have a different hash so resolve the reference
  test "$(git -C $repo1 rev-parse 1.0^{commit})" = $ref
  test "$(git -C $repo1 rev-parse 1.0)" != $ref
}

it_can_put_to_url_with_rebase() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  # make a commit that will require rebasing
  local baseref=$(make_commit_to_file $repo1 some-other-file)

  local ref=$(make_commit $repo2)

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  put_uri_with_rebase $repo1 $src repo > $response

  local rebased_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $rebased_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $rebased_ref
}

it_can_put_to_url_with_rebase_with_tag() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  # make a commit that will require rebasing
  local baseref=$(make_commit_to_file $repo1 some-other-file)

  local ref=$(make_commit $repo2)

  echo some-tag-name > $src/some-tag-file

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  put_uri_with_rebase_with_tag $repo1 $src some-tag-file repo > $response

  local rebased_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $rebased_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $rebased_ref
  test "$(git -C $repo1 rev-parse some-tag-name)" = $rebased_ref
}

it_can_put_to_url_with_rebase_with_tag_and_prefix() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  # make a commit that will require rebasing
  local baseref=$(make_commit_to_file $repo1 some-other-file)

  local ref=$(make_commit $repo2)

  echo 1.0 > $src/some-tag-file

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  put_uri_with_rebase_with_tag_and_prefix $repo1 $src some-tag-file v repo > $response

  local rebased_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $rebased_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $rebased_ref
  test "$(git -C $repo1 rev-parse v1.0)" = $rebased_ref
}

it_can_put_to_url_with_only_tag() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  # create a tag to push
  git -C $repo2 tag some-only-tag

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_only_tag $repo1 $src repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test ! -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" != $ref
  test "$(git -C $repo1 rev-parse some-only-tag)" = $ref
}

it_can_put_and_set_git_config() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  # create a tag to push
  git -C $repo2 tag some-tag

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  cp ~/.gitconfig ~/.gitconfig.orig

  put_uri_with_config $repo1 $src repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test "$(git config --global core.pager)" == 'true'
  test "$(git config --global credential.helper)" == '!true long command with variables $@'

  mv ~/.gitconfig.orig ~/.gitconfig
}

it_will_fail_put_if_conflicts_and_not_force_push() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local expected_ref=$(make_commit $repo1)
  local unpushable_ref=$(make_commit $repo2)

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local result=$(put_uri $repo1 $src repo | jq -e "
    .version == {ref: $(echo $unpushable_ref | jq -R .)}
  " || false)

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $expected_ref
  test "$(git -C $repo1 log --name-only | grep $unpushable_ref)" = ''
}

it_can_put_and_force_the_push() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)
  local lostref=$(make_commit $repo1)

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_force $repo1 $src repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $ref
  test "$(git -C $repo1 log --name-only | grep $lostref)" = ''
}

it_can_put_to_url_with_only_tag_and_force_the_push() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  # create a tag in the upstream branch
  git -C $repo1 tag some-only-tag

  # create the same tag to push upstream
  git -C $repo2 tag some-only-tag

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_only_tag_with_force $repo1 $src repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test ! -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" != $ref
  test "$(git -C $repo1 rev-parse some-only-tag)" = $ref
}

it_will_fail_put_with_conflicting_tag_and_not_force_push() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local expected_ref=$(make_commit $repo1)
  local unpushable_ref=$(make_commit $repo2)

  # create a tag in the upstream branch
  git -C $repo1 tag some-only-tag

  # create the same tag to push upstream
  git -C $repo2 tag some-only-tag

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local result=$(put_uri_with_only_tag $repo1 $src repo | jq -e "
    .version == {ref: $(echo $unpushable_ref | jq -R .)}
  " || false)

  # switch back to master
  git -C $repo1 checkout master

  test "$(git -C $repo1 rev-parse HEAD)" = $expected_ref
  test "$(git -C $repo1 rev-parse some-only-tag)" = $expected_ref
}

run it_can_put_to_url
run it_returns_branch_in_metadata
run it_can_put_to_url_with_tag
run it_can_put_to_url_with_tag_and_prefix
run it_can_put_to_url_with_tag_and_annotation
run it_can_put_to_url_with_rebase
run it_can_put_to_url_with_rebase_with_tag
run it_can_put_to_url_with_rebase_with_tag_and_prefix
run it_can_put_to_url_with_only_tag
run it_can_put_and_set_git_config
run it_will_fail_put_if_conflicts_and_not_force_push
run it_can_put_and_force_the_push
run it_can_put_to_url_with_only_tag_and_force_the_push
run it_will_fail_put_with_conflicting_tag_and_not_force_push
