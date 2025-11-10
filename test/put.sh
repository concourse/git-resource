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

it_can_put_to_url_with_branch() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local branch="branch-a"
  local ref=$(make_commit_to_branch $repo2 $branch)

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_branch $repo1 $src repo $branch | jq -e "
    .version == {branch: $(echo $branch | jq -R .), ref: $(echo $ref | jq -R .)}
  "

  # switch to branch-a
  git -C $repo1 checkout $branch

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $ref
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

  mkdir -p $src/tag
  echo 1.0 > $src/tag/some-tag-file
  echo yay > $src/tag/some-annotation-file

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_tag_and_annotation $repo1 $src "tag/some-tag-file" "tag/some-annotation-file" repo | jq -e "
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


it_can_put_to_url_with_rebase_strategy_options() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  # create initial commit with a file both will modify
  echo "original" > $repo1/conflict-file
  git -C $repo1 add conflict-file
  git -C $repo1 commit -m "initial"
  git -C $repo2 pull

  # make a commit that will conflict when rebasing
  local baseref=$(make_commit_to_file $repo1 conflict-file)

  # make a conflicting local commit
  echo "local" > $repo2/conflict-file
  git -C $repo2 add conflict-file
  git -C $repo2 commit -m "local change"

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  put_uri_with_rebase_strategy_option $repo1 $src repo "theirs" > $response

  local rebased_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $rebased_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/conflict-file
  test "$(git -C $repo1 rev-parse HEAD)" = $rebased_ref
}

it_can_put_with_rebase_ignore_space_change() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  # create a file with specific spacing
  printf "line1\nline2  \nline3\n" > $repo1/spacefile
  git -C $repo1 add spacefile
  git -C $repo1 commit -m "initial spacing"
  git -C $repo2 pull

  # repo1: change content but keep trailing spaces
  printf "line1-changed\nline2  \nline3\n" > $repo1/spacefile
  git -C $repo1 add spacefile
  git -C $repo1 commit -m "content change"

  # repo2: remove trailing spaces but keep old content
  printf "line1\nline2\nline3-changed\n" > $repo2/spacefile
  git -C $repo2 add spacefile
  git -C $repo2 commit -m "spacing change"

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  put_uri_with_rebase_strategy_option $repo1 $src repo "ignore-space-change" > $response

  local rebased_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $rebased_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  # verify the rebase succeeded and content is merged
  grep "line1-changed" $repo1/spacefile
  grep "line3-changed" $repo1/spacefile
  test "$(git -C $repo1 rev-parse HEAD)" = $rebased_ref
}

it_can_put_with_rebase_multiple_strategy_options_string() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  # create a file with spacing issues
  printf "line1\nline2  \nline3\n" > $repo1/testfile
  git -C $repo1 add testfile
  git -C $repo1 commit -m "initial"
  git -C $repo2 pull

  # repo1: modify line1 and clean up spacing on line2
  printf "line1-remote\nline2\nline3\n" > $repo1/testfile
  git -C $repo1 add testfile
  git -C $repo1 commit -m "remote changes"

  # repo2: modify line3 but keep spacing on line2
  printf "line1\nline2  \nline3-local\n" > $repo2/testfile
  git -C $repo2 add testfile
  git -C $repo2 commit -m "local changes"

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  # This uses both "theirs" and "ignore-space-change"
  put_uri_with_rebase_multiple_options_string $repo1 $src repo > $response

  local rebased_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $rebased_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  # Should have remote's line1 change
  grep "line1-remote" $repo1/testfile
  # Should have local's line3 change (non-conflicting)
  grep "line3-local" $repo1/testfile
  test "$(git -C $repo1 rev-parse HEAD)" = $rebased_ref
}

it_can_put_with_rebase_multiple_strategy_options_array() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  # create a file with spacing issues
  printf "line1\nline2  \nline3\n" > $repo1/testfile
  git -C $repo1 add testfile
  git -C $repo1 commit -m "initial"
  git -C $repo2 pull

  # repo1: modify line1 and clean up spacing on line2
  printf "line1-remote\nline2\nline3\n" > $repo1/testfile
  git -C $repo1 add testfile
  git -C $repo1 commit -m "remote changes"

  # repo2: modify line3 but keep spacing on line2
  printf "line1\nline2  \nline3-local\n" > $repo2/testfile
  git -C $repo2 add testfile
  git -C $repo2 commit -m "local changes"

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  # This uses both "theirs" and "ignore-space-change"
  put_uri_with_rebase_multiple_options_array $repo1 $src repo > $response

  local rebased_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $rebased_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  # Should have remote's line1 change
  grep "line1-remote" $repo1/testfile
  # Should have local's line3 change (non-conflicting)
  grep "line3-local" $repo1/testfile
  test "$(git -C $repo1 rev-parse HEAD)" = $rebased_ref
}

it_can_put_to_url_with_merge_commit() {
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

  put_uri_with_merge $repo1 $src repo > $response

  local merged_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $merged_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file

  test "$(git -C $repo1 rev-parse HEAD)" = $merged_ref

  local latest_merge_ref=$(git -C $repo1 log -n 1 --merges --pretty=format:"%H")

  test $latest_merge_ref = $merged_ref
}

it_chooses_the_unmerged_commit_ref() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  # make a commit that will require rebasing
  local baseref=$(make_commit_to_file $repo1 some-other-file)

  local unmerged_ref=$(make_commit $repo2)

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  put_uri_with_merge_returning_unmerged $repo1 $src repo > $response

  local merged_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $unmerged_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file

  test "$(git -C $repo1 rev-parse HEAD)" = $merged_ref

  local latest_merge_ref=$(git -C $repo1 log -n 1 --merges --pretty=format:"%H")

  test $latest_merge_ref = $merged_ref
}

it_will_fail_put_if_merge_and_rebase_are_set() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local expected_ref=$(make_commit $repo1)
  local unpushable_ref=$(make_commit $repo2)

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local result=$(put_uri_with_merge_and_rebase $repo1 $src repo | jq -e "
    .version == {ref: $(echo $unpushable_ref | jq -R .)}
  " || false)

  # switch back to master
  git -C $repo1 checkout master

  test "$(git -C $repo1 rev-parse HEAD)" = $expected_ref
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

it_can_put_to_url_with_notes() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  echo some-notes > $src/notes-file

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_notes $repo1 $src notes-file repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
    and
  (.metadata | .[] | select(.name == \"branch\") | .value == $(echo master | jq -R .))
  "

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $ref
  test "$(git -C $repo1 notes show)" = some-notes
}

it_can_put_to_url_with_rebase_with_notes() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  echo some-notes > $src/notes-file

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  local response=$(mktemp $TMPDIR/rebased-response.XXXXXX)

  put_uri_with_rebase_with_notes $repo1 $src notes-file repo > $response

  local rebased_ref=$(git -C $repo2 rev-parse HEAD)

  jq -e "
    .version == {ref: $(echo $rebased_ref | jq -R .)}
  " < $response

  # switch back to master
  git -C $repo1 checkout master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $ref
  test "$(git -C $repo1 notes show)" = some-notes
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

it_can_put_with_refs_prefix() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master
  set -x
  put_uri_with_refs_prefix $repo1 $src repo refs/for | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout refs/for/master

  test -e $repo1/some-file
  test "$(git -C $repo1 rev-parse HEAD)" = $ref
}

it_errors_when_there_are_unknown_keys_in_params() {
    local failed_output=$TMPDIR/put-unknown-keys-output
    if put_uri_unknown_keys "some-uri" "some-dest" "some-repo" 2>"$failed_output"; then
        echo "put should have failed"
        return 1
    fi

    grep "Found unknown keys in put params:" "$failed_output"
    grep "unknown_key" "$failed_output"
    grep "other_key" "$failed_output"
}

run it_can_put_to_url
run it_can_put_to_url_with_branch
run it_returns_branch_in_metadata
run it_can_put_to_url_with_tag
run it_can_put_to_url_with_tag_and_prefix
run it_can_put_to_url_with_tag_and_annotation
run it_can_put_to_url_with_notes
run it_can_put_to_url_with_rebase_with_notes
run it_can_put_to_url_with_rebase
run it_can_put_to_url_with_rebase_with_tag
run it_can_put_to_url_with_rebase_with_tag_and_prefix
run it_can_put_to_url_with_rebase_strategy_options
run it_can_put_with_rebase_ignore_space_change
run it_can_put_with_rebase_multiple_strategy_options_string
run it_can_put_with_rebase_multiple_strategy_options_array
run it_will_fail_put_if_merge_and_rebase_are_set
run it_can_put_to_url_with_merge_commit
run it_chooses_the_unmerged_commit_ref
run it_can_put_to_url_with_only_tag
run it_can_put_and_set_git_config
run it_will_fail_put_if_conflicts_and_not_force_push
run it_can_put_and_force_the_push
run it_can_put_to_url_with_only_tag_and_force_the_push
run it_will_fail_put_with_conflicting_tag_and_not_force_push
run it_can_put_with_refs_prefix
run it_errors_when_there_are_unknown_keys_in_params
