#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

check_jq_functionality() {
  # Ensure JQ correctly treats empty input as invalid
  set +e
  jq -e 'type == "string"' </dev/null
  if [ $? -eq 0 ]; then
    echo "WARNING - Outdated JQ - please update! Some tests may incorrectly pass"
  fi
  set -e
}

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

it_fails_if_key_has_password_not_provided() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  local key=$TMPDIR/key-with-passphrase
  ssh-keygen -f $key -N some-passphrase

  local failed_output=$TMPDIR/failed-output
  if check_uri_with_key $repo $key 2>$failed_output; then
    echo "checking should have failed"
    return 1
  fi

  grep "Private key has a passphrase but private_key_passphrase has not been set." $failed_output
}

it_can_unlock_key_with_password() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local passphrase='some passphrase with spaces!'

  local key=$TMPDIR/key-with-passphrase
  ssh-keygen -f $key -N "$passphrase"

  local failed_output=$TMPDIR/failed-output
  check_uri_with_key_and_passphrase $repo $key "$passphrase" 2>$failed_output
}


it_configures_forward_agent() {
  local repo=$(init_repo)
  local key=$TMPDIR/key-no-passphrase

  ssh-keygen -f $key
  check_uri_with_key_and_ssh_agent $repo $key true

  grep "ForwardAgent yes" $HOME/.ssh/config
}

it_skips_forward_agent_configuration() {
  local repo=$(init_repo)
  local key=$TMPDIR/key-no-passphrase

  ssh-keygen -f $key
  check_uri_with_key_and_ssh_agent $repo $key false

  ! grep "ForwardAgent" $HOME/.ssh/config
}

it_configures_private_key_user() {
  local repo=$(init_repo)
  local key=$TMPDIR/key-no-passphrase

  ssh-keygen -f $key
  check_uri_with_key_and_user $repo $key someuser

  grep "User someuser" $HOME/.ssh/config
}

it_skips_private_key_user_configuration() {
  local repo=$(init_repo)
  local key=$TMPDIR/key-no-passphrase

  ssh-keygen -f $key
  check_uri_with_key $repo $key

  ! grep "^User " $HOME/.ssh/config
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

it_can_check_with_submodule_credentials() {
  local repo=$(init_repo)
  local ref=$(make_commit "$repo")
  local expected_netrc
  expected_netrc=$(cat <<EOF
machine host1 login user2 password pass2
default login user1 password pass1
EOF
)
  check_uri_with_submodule_credentials "$repo" "user1" "pass1" "host1" "user2" "pass2" | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "
  echo "Generated netrc $(cat ${HOME}/.netrc)"
  echo "Expected netrc $expected_netrc"
  [ "$(cat $HOME/.netrc)" = "$expected_netrc" ]

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

it_checks_given_paths_ci_skip_disabled() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_commit_to_file $repo file-a)
  local ref3=$(make_commit_to_file $repo file-a)
  check_uri_from_paths_disable_ci_skip $repo $ref1 "file-a" | jq -e "
  . == [
    {ref: $(echo $ref1 | jq -R .)},
    {ref: $(echo $ref2 | jq -R .)},
    {ref: $(echo $ref3 | jq -R .)}
  ]
"
}

it_checks_given_paths_on_branch() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file_on_branch_with_path $repo dummy file-b master)
  echo $ref1
  local ref2=$(make_commit_to_file_on_branch_with_path $repo dummy file-b master)
  echo $ref2
  local ref3=$(make_commit_to_file_on_branch_with_path $repo dummy file-b newbranch)
  echo $ref3
  local result=$(check_uri_from_paths_with_branch $repo newbranch "dummy/*")
  echo result

  check_uri_from_paths_with_branch $repo newbranch "dummy/*"| jq -e "
    . == [{ref: $(echo $ref3 | jq -R .)}]
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

it_skips_excluded_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_future $repo "not skipped")
  local ref3=$(make_commit $repo "should skip this commit")
  local ref4=$(make_commit $repo)

  check_uri_with_filter $repo $ref1 "exclude" "should skip" | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref4 | jq -R .)}
    ]
  "
}

it_skips_non_included_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_future $repo "not skipped commit")
  local ref3=$(make_commit $repo "not skipped commit number_two")
  local ref4=$(make_commit $repo "should skip this commit")
  local ref5=$(make_commit $repo)

  check_uri_with_filter $repo $ref1 "include" "not skipped" | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_skips_all_non_included_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_future $repo "not skipped commit")
  local ref3=$(make_commit $repo "not skipped commit number_two")
  local ref4=$(make_commit $repo "should skip this commit")
  local ref5=$(make_commit $repo)

  check_uri_with_filter $repo $ref1 "include" 'not\nskipped\nnumber_two' "true"| jq -e "
    . == [
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_skips_excluded_commits_conventional() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo "chore: update a thing")
  local ref3=$(make_commit $repo "chore(release): auto-publish")
  local ref4=$(make_commit $repo "fix: a bug")
  local ref5=$(make_commit $repo)

  check_uri_with_filter $repo $ref1 "exclude" "chore(release):" | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref4 | jq -R .)},
      {ref: $(echo $ref5 | jq -R .)}
    ]
  "
}

it_skips_non_included_and_excluded_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo "not skipped commit")
  local ref3=$(make_commit $repo "not skipped sometimes")
  local ref4=$(make_commit $repo)

  check_uri_with_filters $repo $ref1 "not skipped" "sometimes" | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)}
    ]
  "
}

it_rejects_filter_with_incorrect_format() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)

  set +e
  output=$(
    jq --arg uri "$(init_repo)" \
      --arg ref "$(make_commit "$repo")" \
      -n '{
      source: {
        $uri,
        commit_filter: {
          include: "a string, not an array",
        }
      },
      version: {
        $ref
      }
    }' | ${resource_dir}/check | tee /dev/stderr
  )
  exit_code=$?
  set -e

  test $exit_code -ne 0
}

it_does_not_skip_marked_commits_when_disable_skip_configured() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_future $repo)
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

it_can_check_with_tag_and_path_match_filter() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_annotated_tag $repo "1.0-staging" "tag 1" true)
  local ref3=$(make_commit_to_file $repo file-b)
  local ref4=$(make_annotated_tag $repo "1.0-production" "tag 2" true)
  local ref5=$(make_annotated_tag $repo "2.0-staging" "tag 3" true)
  local ref6=$(make_commit_to_file $repo file-c)
  local ref7=$(make_annotated_tag $repo "2.0-staging" "tag 5" true)
  local ref8=$(make_commit_to_file $repo file-b)
  local ref9=$(make_annotated_tag $repo "2.0-production" "tag 4" true)
  local ref10=$(make_commit_to_file $repo file-c)

  check_uri_with_tag_and_path_filter $repo "2*" "match_tagged" file-c | jq -e "
    . == [{ref: \"2.0-staging\", commit: \"$ref6\"}]
  "

  # No matching files. ref3's tag was replaced by the tag on ref6 - which does not path match
  check_uri_with_tag_and_path_filter $repo "*-staging" "match_tagged" file-b | jq -e "
    . == []
  "

  # Although multiple tagged commits modify the files, ref8 is the latest (and version_depth is default 1)
  check_uri_with_tag_and_path_filter $repo "*" "match_tagged" file-b file-c | jq -e "
    . == [
      {ref: \"2.0-production\", commit: \"$ref8\"}
    ]
  "

  # file-f was never created
  check_uri_with_tag_and_path_filter $repo "*" "match_tagged" file-f | jq -e "
    . == []
  "

  # no tags matching 4.0-*
  check_uri_with_tag_and_path_filter $repo "4.0-*" "match_tagged" file-c | jq -e "
    . == []
  "
}

it_can_check_with_tag_and_path_match_ancestors_filter() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_annotated_tag $repo "1.0-staging" "tag 1" true)
  local ref3=$(make_commit_to_file $repo file-b)
  local ref4=$(make_annotated_tag $repo "1.0-production" "tag 2" true)
  local ref5=$(make_annotated_tag $repo "2.0-staging" "tag 3" true)
  local ref6=$(make_commit_to_file $repo file-c)
  local ref7=$(make_annotated_tag $repo "2.0-staging" "tag 5" true)
  local ref8=$(make_commit_to_file $repo file-b)
  local ref9=$(make_annotated_tag $repo "2.0-production" "tag 4" true)
  local ref10=$(make_commit_to_file $repo file-c)

  # ref10 is the most recent to modify file-c, but the latest 2* tag is before it. Therefore ref6 matches.
  check_uri_with_tag_and_path_filter $repo "2*" "match_tag_ancestors" file-c | jq -e "
    . == [{ref: \"$ref6\"}]
  "

  # ref3 is the most recent commit to modify file-b, and following commits have -staging tags
  check_uri_with_tag_and_path_filter $repo "*-staging" "match_tag_ancestors" file-b | jq -e "
    . == [{ref: \"$ref3\"}]
  "

  # although no 2.* tagged commits modified file-a, they follow on from commits that did
  check_uri_with_tag_and_path_filter $repo "2.*" "match_tag_ancestors" file-a | jq -e "
    . == [{ref: \"$ref1\"}]
  "

  # no commits creating file-c are followed by 1.* tags
  check_uri_with_tag_and_path_filter $repo "1.*" "match_tag_ancestors" file-c | jq -e "
    . == []
  "

  # Although multiple tagged commits modify the files, ref8 is the latest (and version_depth is default 1)
  check_uri_with_tag_and_path_filter $repo "*" "match_tag_ancestors" file-b file-c | jq -e "
    . == [
      {ref: \"$ref8\"}
    ]
  "

  # file-f was never created
  check_uri_with_tag_and_path_filter $repo "*" "match_tag_ancestors" file-f | jq -e "
    . == []
  "

  # no tags matching 4.0-*
  check_uri_with_tag_and_path_filter $repo "4.0-*" "match_tag_ancestors" file-c | jq -e "
    . == []
  "
}

it_can_check_with_tag_regex() {
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

  check_uri_with_tag_regex $repo ".*-staging" | jq -e "
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
  check_uri_with_tag_filter_from $repo "*-staging" "2.0-staging" 2 | jq -e "
    . == [{ref: \"2.0-staging\", commit: \"$ref5\"}, {ref: \"3.0-staging\", commit: \"$ref9\"}]
  "
}

it_can_check_with_tag_regex_with_cursor() {
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

  x=$(check_uri_with_tag_regex_from $repo ".*-staging" "2.0-staging")
  check_uri_with_tag_regex_from $repo ".*-staging" "2.0-staging" 2 | jq -e "
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

it_can_check_with_tag_regex_over_all_branches() {
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

  check_uri_with_tag_regex $repo ".*-staging" | jq -e "
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

  check_uri_with_tag_filter_from $repo "*-staging" "2.0-staging" 2 | jq -e "
    . == [{ref: \"2.0-staging\", commit: \"$ref6\"}, {ref: \"3.0-staging\", commit: \"$ref10\"}]
  "
}

it_can_check_with_tag_regex_over_all_branches_with_cursor() {
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

  check_uri_with_tag_regex_from $repo ".*-staging" "2.0-staging" 2 | jq -e "
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

it_can_check_with_tag_regex_with_bogus_ref() {
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


  check_uri_with_tag_regex_from $repo ".*-staging" "bogus-ref" | jq -e "
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

it_can_check_with_tag_regex_with_replaced_tags() {

  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_annotated_tag $repo "staging" "tag branch-a")
  # see that the tag is initially ref1
  check_uri_with_tag_regex $repo "staging" | jq -e "
    . == [{ref: \"staging\", commit: \"$ref1\"}]
  "

  local ref3=$(make_commit_to_branch $repo branch-a)
  local ref4=$(make_annotated_tag $repo "staging" "tag branch-a")

  check_uri_with_tag_regex $repo "staging" | jq -e "
    . == [{ref: \"staging\", commit: \"$ref3\"}]
  "
}

it_can_check_with_tag_filter_given_branch_first_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_annotated_tag $repo "test.tag.1" "tag branch-a")
  # see that the tag on non-master branch doesn't get picked up
  check_uri_with_tag_filter_given_branch $repo "test.tag.*" "master" | jq -e "
    . == []
  "

  # make a new tag on master, ensure it gets picked up
  local ref3=$(make_commit_to_branch $repo master)
  local ref4=$(make_annotated_tag $repo "test.tag.2" "tag branch-a")

  check_uri_with_tag_filter_given_branch $repo "test.tag.*" "master" | jq -e "
    . == [{ref: \"test.tag.2\", commit: \"$ref3\"}]
  "
}

it_can_check_with_tag_regex_given_branch_first_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_annotated_tag $repo "test.tag.1" "tag branch-a")
  # see that the tag on non-master branch doesn't get picked up
  check_uri_with_tag_regex_given_branch $repo "test.tag\..*" "master" | jq -e "
    . == []
  "

  # make a new tag on master, ensure it gets picked up
  local ref3=$(make_commit_to_branch $repo master)
  local ref4=$(make_annotated_tag $repo "test.tag.2" "tag branch-a")

  check_uri_with_tag_regex_given_branch $repo "test.tag\..*" "master" | jq -e "
    . == [{ref: \"test.tag.2\", commit: \"$ref3\"}]
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

it_checks_lastest_commit() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_future $repo)
  local ref2=$(make_commit $repo)

  check_uri $repo | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "
}

it_can_check_a_repo_having_multiple_root_commits() {
  local repo=$(init_repo)
  local ref1=$(get_initial_ref $repo)
  local ref2=$(make_commit $repo)

  # Make the second root commit, the commit tree will look like:
  #
  #   * ref3
  #   |\
  #   | * second root
  #   * ref2
  #   * ref1
  #
  # Where ref1 is the first commit of the repo, and "second root" is created
  # to simulator the issue in https://github.com/concourse/git-resource/pull/324,
  # that is also a root commit.
  git -C $repo checkout --orphan temp $ref2
  git -C $repo commit -m "second root" --allow-empty
  git -C $repo checkout master
  git -C $repo merge temp --allow-unrelated-histories -m "merge commit"
  ref3=$(git -C $repo rev-parse HEAD)

  check_uri_from $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_can_check_a_repo_having_multiple_root_commits_from_the_orphan_commit() {
  local repo=$(init_repo)
  local ref1=$(get_initial_ref $repo)
  local ref2=$(make_commit $repo)

  # Same as above, but where the current version is the orphan commit.
  git -C $repo checkout --orphan temp $ref2
  git -C $repo commit -m "second root" --allow-empty
  git -C $repo checkout master
  git -C $repo merge temp --allow-unrelated-histories -m "merge commit"
  second_root=$(git -C $repo rev-parse HEAD^2)
  ref3=$(git -C $repo rev-parse HEAD)

  check_uri_from $repo $second_root | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)},
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_checks_with_version_depth() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_future $repo)
  local ref2=$(make_commit $repo)
  local ref3=$(make_commit $repo)
  check_uri_with_version_depth $repo 2 | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_checks_uri_with_tag_filter_and_version_depth() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  make_annotated_tag $repo "test.tag.1" "tag ref1"
  local ref2=$(make_commit $repo)
  make_annotated_tag $repo "test.tag.2" "tag ref2"
  local ref3=$(make_commit $repo)
  make_annotated_tag $repo "test.badtag.3" "tag ref3"
  local ref4=$(make_commit $repo)
  make_annotated_tag $repo "test.tag.4" "tag ref4"
  check_uri_with_tag_filter_and_version_depth $repo 2 "test.tag.*" | jq -e "
    . ==   [
      {
        ref: \"test.tag.2\",
        commit: $(echo $ref2 | jq -R .)
      },
      {
        ref: \"test.tag.4\",
        commit: $(echo $ref4 | jq -R .)
      }
    ]"
}

run check_jq_functionality
run it_can_check_from_head
run it_can_check_from_a_ref
run it_can_check_from_a_first_commit_in_repo
run it_can_check_from_a_bogus_sha
run it_skips_ignored_paths
run it_checks_given_paths
run it_checks_given_paths_ci_skip_disabled
run it_checks_given_paths_on_branch
run it_checks_given_glob_paths
run it_checks_given_ignored_paths
run it_can_check_when_not_ff
run it_skips_marked_commits
run it_skips_marked_commits_with_no_version
run it_skips_excluded_commits
run it_skips_excluded_commits_conventional
run it_skips_non_included_commits
run it_skips_non_included_and_excluded_commits
run it_rejects_filter_with_incorrect_format
run it_skips_all_non_included_commits
run it_does_not_skip_marked_commits_when_disable_skip_configured
run it_fails_if_key_has_password_not_provided
run it_can_unlock_key_with_password
run it_configures_forward_agent
run it_skips_forward_agent_configuration
run it_can_check_with_credentials
run it_can_check_with_submodule_credentials
run it_clears_netrc_even_after_errors
run it_can_check_empty_commits
run it_can_check_with_tag_filter
run it_can_check_with_tag_regex
run it_can_check_with_tag_filter_with_cursor
run it_can_check_with_tag_regex_with_cursor
run it_can_check_with_tag_filter_over_all_branches
run it_can_check_with_tag_regex_over_all_branches
run it_can_check_with_tag_filter_over_all_branches_with_cursor
run it_can_check_with_tag_regex_over_all_branches_with_cursor
run it_can_check_with_tag_filter_with_bogus_ref
run it_can_check_with_tag_regex_with_bogus_ref
run it_can_check_with_tag_filter_with_replaced_tags
run it_can_check_with_tag_regex_with_replaced_tags
run it_can_check_with_tag_and_path_match_filter
run it_can_check_with_tag_and_path_match_ancestors_filter
run it_can_check_from_head_only_fetching_single_branch
run it_can_check_and_set_git_config
run it_can_check_from_a_ref_and_only_show_merge_commit
run it_can_check_from_a_ref_with_paths_merged_in
run it_can_check_with_tag_filter_given_branch_first_ref
run it_can_check_with_tag_regex_given_branch_first_ref
run it_checks_lastest_commit
run it_can_check_a_repo_having_multiple_root_commits
run it_can_check_a_repo_having_multiple_root_commits_from_the_orphan_commit
run it_checks_with_version_depth
run it_checks_uri_with_tag_filter_and_version_depth
