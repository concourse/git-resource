#!/bin/sh

set -e

source $(dirname $0)/helpers.sh

it_can_check_from_head() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  check_uri $repo | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "
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

it_can_check_from_a_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)
  local ref3=$(make_commit $repo)

  check_uri_from $repo $ref1 | jq -e "
    . == [
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

  check_uri_from_ignoring $repo $ref1 "file-c" | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "

  local ref4=$(make_commit_to_file $repo file-b)

  check_uri_ignoring $repo "file-c" | jq -e "
    . == [{ref: $(echo $ref4 | jq -R .)}]
  "

  check_uri_from_ignoring $repo $ref1 "file-c" | jq -e "
    . == [
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

it_checks_given_ignored_paths() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_commit_to_file $repo file-b)
  local ref3=$(make_commit_to_file $repo some-file)

  check_uri_paths_ignoring $repo 'file-*' 'file-b' | jq -e "
    . == [{ref: $(echo $ref1 | jq -R .)}]
  "

  check_uri_from_paths_ignoring $repo $ref1 'file-*' 'file-b' | jq -e "
    . == []
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
      {ref: $(echo $ref5 | jq -R .)},
      {ref: $(echo $ref6 | jq -R .)}
    ]
  "

  check_uri_from_paths_ignoring $repo $ref1 'file-*' 'file-b' 'file-c' | jq -e "
    . == [
      {ref: $(echo $ref5 | jq -R .)}
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
  local ref3=$(make_commit $repo)

  check_uri_from $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_skips_marked_commits_with_no_version() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_be_skipped $repo)
  local ref3=$(make_commit_to_be_skipped $repo)

  check_uri $repo | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)}
    ]
  "
}

run it_can_check_from_head
run it_can_check_from_a_ref
run it_can_check_from_a_bogus_sha
run it_skips_ignored_paths
run it_checks_given_paths
run it_checks_given_ignored_paths
run it_can_check_when_not_ff
run it_skips_marked_commits
run it_skips_marked_commits_with_no_version
run it_fails_if_key_has_password
