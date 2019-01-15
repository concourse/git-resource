#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

it_can_check_from_head() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  check_uri $repo | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "
}

it_can_check_from_head_only_fetching_single_branch() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  local cachedir="$TMPDIR/git-resource-repo-cache"

  check_uri_with_branch $repo "master" | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "

  ! git -C $cachedir rev-parse origin/bogus
}

it_fails_if_key_has_password() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  local key=$TMPDIR/key-with-passphrase
  ssh-keygen -f $key -N some-passphrase

  local failed_output=$TMPDIR/failed-output
  if check_uri_with_key $repo $key 2>$failed_output; then
    echo "checking should have failed"
    return 1
  fi

  grep "Private keys with passphrases are not supported." $failed_output
}

it_can_check_with_credentials() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  check_uri_with_credentials $repo "user1" "pass1" | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "

  # only check that the expected credential helper is set
  # because it is not easily possible to simulate a git http backend that needs credentials
  local expected_netrc="default login user1 password pass1"
  [ "$(cat $HOME/.netrc)" = "$expected_netrc" ]

  # make sure it clears out .netrc for this request without credentials
  check_uri_with_credentials $repo "" "" | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "
  [ ! -f "$HOME/.netrc" ]
}

it_clears_netrc_even_after_errors() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  if check_uri_with_credentials "non_existent_repo" "user1" "pass1" ; then
    exit 1
  fi

  local expected_netrc="default login user1 password pass1"
  [ "$(cat $HOME/.netrc)" = "$expected_netrc" ]

  # make sure it clears out .netrc for this request without credentials
  if check_uri_with_credentials "non_existent_repo" "" "" ; then
    exit 1
  fi
  [ ! -f "$HOME/.netrc" ]
}

it_can_check_from_a_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)
  local ref3=$(make_commit $repo)

  check_uri_from $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_can_check_from_a_ref_and_only_show_merge_commit() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)
  local branch_ref1=$(make_commit_to_file_on_branch $repo some-branch-file some-branch)
  local ref3=$(make_commit $repo)

  check_uri_from $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "

  local ref4=$(merge_branch $repo master some-branch)

  check_uri_from $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)},
      {ref: $(echo $ref4 | jq -R .)}
    ]
  "
}

it_can_check_from_a_ref_with_paths_merged_in() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo some-master-file)
  local ref2=$(make_commit $repo)
  local branch_ref1=$(make_commit_to_file_on_branch $repo some-branch-file some-branch)
  local ref3=$(make_commit_to_file $repo some-master-file)

  check_uri_from_paths $repo $ref1 some-master-file some-branch-file | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "

  local ref4=$(merge_branch $repo master some-branch)

  check_uri_from_paths $repo $ref1 some-master-file some-branch-file | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)},
      {ref: $(echo $ref4 | jq -R .)}
    ]
  "
}

it_can_check_from_a_first_commit_in_repo() {
  local repo=$(init_repo)
  local initial_ref=$(get_initial_ref $repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)
  local ref3=$(make_commit $repo)

  check_uri_from $repo $initial_ref | jq -e "
    . == [
      {ref: $(echo $initial_ref | jq -R .)},
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_can_check_from_a_bogus_sha() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)

  check_uri_from $repo "bogus-ref" | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "
}

it_skips_ignored_paths() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_commit_to_file $repo file-b)
  local ref3=$(make_commit_to_file $repo file-c)

  check_uri_ignoring $repo "file-c" | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "

  check_uri_from_ignoring $repo $ref1 "file-a" | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "

  check_uri_from_ignoring $repo $ref1 "file-c" | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)}
    ]
  "

  local ref4=$(make_commit_to_file $repo file-b)

  check_uri_ignoring $repo "file-c" | jq -e "
    . == [{ref: $(echo $ref4 | jq -R .)}]
  "

  check_uri_from_ignoring $repo $ref1 "file-c" | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref4 | jq -R .)}
    ]
  "
}

it_checks_given_paths() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_commit_to_file $repo file-b)
  local ref3=$(make_commit_to_file $repo file-c)

  check_uri_paths $repo "file-c" | jq -e "
    . == [{ref: $(echo $ref3 | jq -R .)}]
  "

  check_uri_from_paths $repo $ref1 "file-c" | jq -e "
    . == [{ref: $(echo $ref3 | jq -R .)}]
  "

  local ref4=$(make_commit_to_file $repo file-b)

  check_uri_paths $repo "file-c" | jq -e "
    . == [{ref: $(echo $ref3 | jq -R .)}]
  "

  local ref5=$(make_commit_to_file $repo file-c)

  check_uri_from_paths $repo $ref1 "file-c" | jq -e "
    . == [
      {ref: $(echo $ref3 | jq -R .)},
      {ref: $(echo $ref5 | jq -R .)}
    ]
  "
}

it_checks_given_glob_paths() { # issue gh-120
  local repo=$(init_repo)
  mkdir -p $repo/a/b
  make_commit_to_file $repo a/file > /dev/null
  local ref1=$(make_commit_to_file $repo a/b/file)
  check_uri_paths $repo "**/file" | jq -e "
    . == [{ref: $(echo $ref1 | jq -R .)}]
  "
}

it_checks_given_ignored_paths() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_commit_to_file $repo file-b)
  local ref3=$(make_commit_to_file $repo some-file)

  check_uri_paths_ignoring $repo 'file-*' 'file-b' | jq -e "
    . == [{ref: $(echo $ref1 | jq -R .)}]
  "

  check_uri_from_paths_ignoring $repo $ref1 'file-*' 'file-b' | jq -e "
    . == [{ref: $(echo $ref1 | jq -R .)}]
  "

  check_uri_from_paths_ignoring $repo $ref1 'file-*' 'file-a' | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "

  local ref4=$(make_commit_to_file $repo file-b)

  check_uri_paths_ignoring $repo 'file-*' 'file-b' | jq -e "
    . == [{ref: $(echo $ref1 | jq -R .)}]
  "

  local ref5=$(make_commit_to_file $repo file-a)

  check_uri_paths_ignoring $repo 'file-*' 'file-b' | jq -e "
    . == [{ref: $(echo $ref5 | jq -R .)}]
  "

  local ref6=$(make_commit_to_file $repo file-c)

  local ref7=$(make_commit_to_file $repo some-file)

  check_uri_from_paths_ignoring $repo $ref1 'file-*' 'file-b' | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref5 | jq -R .)},
      {ref: $(echo $ref6 | jq -R .)}
    ]
  "

  check_uri_from_paths_ignoring $repo $ref1 'file-*' 'file-b' 'file-c' | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref5 | jq -R .)}
    ]
  "
  local ref8=$(make_commit_to_file $repo another-file)

  check_uri_paths_ignoring $repo '*-file' 'another-file' | jq -e "
    . == [
      {ref: $(echo $ref7 | jq -R .)}
    ]
  "

  check_uri_paths_ignoring $repo '.' 'file-*' | jq -e "
    . == [
      {ref: $(echo $ref8 | jq -R .)}
    ]
  "
}

it_can_check_when_not_ff() {
  local repo=$(init_repo)
  local other_repo=$(init_repo)

  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)

  local ref3=$(make_commit $other_repo)

  check_uri $other_repo

  cd "$TMPDIR/git-resource-repo-cache"

  # do this so we get into a situation that git can't resolve by rebasing
  git config branch.autosetuprebase never

  # set my remote to be the other git repo
  git remote remove origin
  git remote add origin $repo/.git

  # fetch so we have master available to track
  git fetch

  # setup tracking for my branch
  git branch -u origin/master HEAD

  check_uri $other_repo | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "
}

it_skips_marked_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_be_skipped $repo)
  local ref3=$(make_commit $repo "not ci skipped")
  local ref4=$(make_commit_to_be_skipped2 $repo)
  local ref5=$(make_commit $repo)

  check_uri_from $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)},
      {ref: $(echo $ref5 | jq -R .)}
    ]
  "
}

it_skips_marked_commits_with_no_version() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_be_skipped $repo)
  local ref3=$(make_commit_to_be_skipped2 $repo)

  check_uri $repo | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)}
    ]
  "
}

it_does_not_skip_marked_commits_when_disable_skip_configured() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_be_skipped $repo)
  local ref3=$(make_commit $repo)
  local ref4=$(make_commit_to_be_skipped2 $repo)

  check_uri_disable_ci_skip $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)},
      {ref: $(echo $ref4 | jq -R .)}
    ]
  "
}

it_can_check_empty_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_empty_commit $repo)

  check_uri_from $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)}
    ]
  "
}

it_can_check_from_head_with_empty_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_empty_commit $repo)

  check_uri $repo | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "
}

it_can_check_with_tag_filter() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_annotated_tag $repo "1.0-staging" "tag 1")
  local ref3=$(make_commit $repo)
  local ref4=$(make_annotated_tag $repo "1.0-production" "tag 2")
  local ref5=$(make_annotated_tag $repo "2.0-staging" "tag 3")
  local ref6=$(make_commit $repo)
  local ref7=$(make_annotated_tag $repo "2.0-staging" "tag 5")
  local ref8=$(make_commit $repo)
  local ref9=$(make_annotated_tag $repo "2.0-production" "tag 4")
  local ref10=$(make_commit $repo)

  check_uri_with_tag_filter $repo "*-staging" | jq -e "
    . == [{ref: \"2.0-staging\", commit: \"$ref6\"}]
  "
}

it_can_check_with_tag_filter_with_cursor() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_annotated_tag $repo "1.0-staging" "a tag")
  local ref3=$(make_commit $repo)
  local ref4=$(make_annotated_tag $repo "1.0-production" "another tag")
  local ref5=$(make_commit $repo)
  local ref6=$(make_annotated_tag $repo "2.0-staging" "tag 3")
  local ref7=$(make_commit $repo)
  local ref8=$(make_annotated_tag $repo "2.0-production" "tag 4")
  local ref9=$(make_commit $repo)
  local ref10=$(make_annotated_tag $repo "3.0-staging" "tag 5")
  local ref11=$(make_commit $repo)
  local ref12=$(make_annotated_tag $repo "3.0-production" "tag 6")
  local ref13=$(make_commit $repo)

  x=$(check_uri_with_tag_filter_from $repo "*-staging" "2.0-staging")
  check_uri_with_tag_filter_from $repo "*-staging" "2.0-staging" | jq -e "
    . == [{ref: \"2.0-staging\", commit: \"$ref5\"}, {ref: \"3.0-staging\", commit: \"$ref9\"}]
  "
}

it_can_check_with_tag_filter_over_all_branches() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_annotated_tag $repo "1.0-staging" "a tag")
  local ref3=$(make_commit_to_branch $repo branch-a)
  local ref4=$(make_annotated_tag $repo "1.0-production" "another tag")
  local ref5=$(make_commit_to_branch $repo branch-a)
  local ref6=$(make_annotated_tag $repo "2.0-staging" "tag 3")
  local ref7=$(make_commit_to_branch $repo branch-a)
  local ref8=$(make_annotated_tag $repo "2.0-production" "tag 4")
  local ref9=$(make_commit_to_branch $repo branch-a)
  local ref10=$(make_annotated_tag $repo "3.0-staging" "tag 5")
  local ref11=$(make_commit_to_branch $repo branch-a)
  local ref12=$(make_annotated_tag $repo "3.0-production" "tag 6")
  local ref13=$(make_commit_to_branch $repo branch-a)

  check_uri_with_tag_filter $repo "*-staging" | jq -e "
    . == [{ref: \"3.0-staging\", commit: \"$ref9\"}]
  "
}

it_can_check_with_tag_filter_over_all_branches_with_cursor() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_annotated_tag $repo "1.0-staging" "a tag")
  local ref3=$(make_commit_to_branch $repo branch-a)
  local ref4=$(make_annotated_tag $repo "1.0-production" "another tag")
  local ref5=$(make_annotated_tag $repo "2.0-staging" "tag 3")
  local ref6=$(make_commit_to_branch $repo branch-a)
  local ref7=$(make_annotated_tag $repo "2.0-staging" "tag 3")
  local ref8=$(make_commit_to_branch $repo branch-a)
  local ref9=$(make_annotated_tag $repo "2.0-production" "tag 4")
  local ref10=$(make_commit_to_branch $repo branch-a)
  local ref11=$(make_annotated_tag $repo "3.0-staging" "tag 5")
  local ref12=$(make_commit_to_branch $repo branch-a)
  local ref13=$(make_annotated_tag $repo "3.0-production" "tag 6")
  local ref14=$(make_commit_to_branch $repo branch-a)

  check_uri_with_tag_filter_from $repo "*-staging" "2.0-staging" | jq -e "
    . == [{ref: \"2.0-staging\", commit: \"$ref6\"}, {ref: \"3.0-staging\", commit: \"$ref10\"}]
  "
}

it_can_check_with_tag_filter_with_bogus_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_annotated_tag $repo "1.0-staging" "tag 1")
  local ref3=$(make_commit $repo)
  local ref4=$(make_annotated_tag $repo "1.0-production" "tag 2")
  local ref5=$(make_commit $repo)
  local ref6=$(make_annotated_tag $repo "2.0-staging" "tag 3")
  local ref7=$(make_commit $repo)
  local ref8=$(make_annotated_tag $repo "2.0-production" "tag 4")
  local ref9=$(make_commit $repo)


  check_uri_with_tag_filter_from $repo "*-staging" "bogus-ref" | jq -e "
    . == [{ref: \"2.0-staging\", commit: \"$ref5\"}]
  "
}

it_can_check_with_tag_filter_with_replaced_tags() {

  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_annotated_tag $repo "staging" "tag branch-a")
  # see that the tag is initially ref1
  check_uri_with_tag_filter $repo "staging" | jq -e "
    . == [{ref: \"staging\", commit: \"$ref1\"}]
  "

  local ref3=$(make_commit_to_branch $repo branch-a)
  local ref4=$(make_annotated_tag $repo "staging" "tag branch-a")

  check_uri_with_tag_filter $repo "staging" | jq -e "
    . == [{ref: \"staging\", commit: \"$ref3\"}]
  "
}

it_can_check_and_set_git_config() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  cp ~/.gitconfig ~/.gitconfig.orig

  check_uri_with_config $repo | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "
  test "$(git config --global core.pager)" == 'true'
  test "$(git config --global credential.helper)" == '!true long command with variables $@'

  mv ~/.gitconfig.orig ~/.gitconfig
}

run it_can_check_from_head
run it_can_check_from_a_ref
run it_can_check_from_a_first_commit_in_repo
run it_can_check_from_a_bogus_sha
run it_skips_ignored_paths
run it_checks_given_paths
run it_checks_given_glob_paths
run it_checks_given_ignored_paths
run it_can_check_when_not_ff
run it_skips_marked_commits
run it_skips_marked_commits_with_no_version
run it_does_not_skip_marked_commits_when_disable_skip_configured
run it_fails_if_key_has_password
run it_can_check_with_credentials
run it_clears_netrc_even_after_errors
run it_can_check_empty_commits
run it_can_check_with_tag_filter
run it_can_check_with_tag_filter_with_cursor
run it_can_check_with_tag_filter_over_all_branches
run it_can_check_with_tag_filter_over_all_branches_with_cursor
run it_can_check_with_tag_filter_with_bogus_ref
run it_can_check_with_tag_filter_with_replaced_tags
run it_can_check_from_head_only_fetching_single_branch
run it_can_check_and_set_git_config
run it_can_check_from_a_ref_and_only_show_merge_commit
run it_can_check_from_a_ref_with_paths_merged_in
