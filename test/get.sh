#!/bin/bash

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

  get_uri_with_branch $repo "master" $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  ! git -C $dest rev-parse origin/bogus
}

it_omits_empty_branch_in_metadata() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_commit_to_branch $repo branch-a)
  local ref3=$(make_commit_to_branch $repo branch-a)
  local ref4=$(make_commit $repo)

  local dest=$TMPDIR/destination

  get_uri_at_ref $repo $ref2 $dest | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
    and
    ([.metadata | .[] | select(.name == \"branch\")] == [])
  "
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

  rm -rf $dest

  get_uri_at_ref $repo $ref2 $dest | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
    and
    (.metadata | .[] | select(.name == \"branch\") | .value == $(echo master | jq -R .))
  "
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

it_can_use_submodules_without_perl_warning() {
  local repo=$(init_repo_with_submodule | cut -d "," -f1)
  local dest=$TMPDIR/destination

  output=$(get_uri_with_submodules_all "file://"$repo 1 $dest 2>&1)
  ! echo "${output}" | grep "perl: not found"
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

it_can_get_from_url_at_depth_at_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)

  local dest=$TMPDIR/destination

  get_uri_at_depth_at_ref "file://$repo" 1 $ref1 $dest | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  rm -rf $dest

  get_uri_at_depth_at_ref "file://$repo" 1 $ref2 $dest | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2
}

it_falls_back_to_deep_clone_if_ref_not_found() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)

  # 128 is the threshold when it starts doing a deep clone
  for (( i = 0; i < 128; i++ )); do
    make_commit $repo >/dev/null
  done

  local dest=$TMPDIR/destination

  ( get_uri_at_depth_at_ref "file://$repo" 1 $ref1 $dest 3>&2- 2>&1- 1>&3- 3>&- | tee $TMPDIR/stderr ) 3>&1- 1>&2- 2>&3- 3>&- | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  echo "testing for msg 1" >&2
  for d in 1 2 4 8 16 32 64 128; do
    grep "Could not find ref ${ref1} in a shallow clone of depth ${d}" <$TMPDIR/stderr
  done
  echo "test for msg 1 done" >&2

  for d in 2 4 8 16 32 64 128; do
    grep "Deepening the shallow clone to depth ${d}..." <$TMPDIR/stderr
  done

  grep "Reached depth threshold 128, falling back to deep clone..." <$TMPDIR/stderr
}

it_does_not_enter_an_infinite_loop_if_the_ref_cannot_be_found_and_depth_is_set() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=0123456789abcdef0123456789abcdef01234567

  local dest=$TMPDIR/destination

  set +e
  output=$(get_uri_at_depth_at_ref "file://$repo" 1 $ref2 $dest 2>&1)
  exit_code=$?
  set -e

  echo $output $exit_code
  test "${exit_code}" = 128
  echo "${output}" | grep "Reached max depth of the origin repo while deepening the shallow clone, it's a deep clone now"
  echo "${output}" | grep "fatal: reference is not a tree: $ref2"
}

it_honors_the_depth_flag_for_submodules() {
  local repo_with_submodule_info=$(init_repo_with_submodule)
  local project_folder=$(echo $repo_with_submodule_info | cut -d "," -f1)
  local submodule_folder=$(echo $repo_with_submodule_info | cut -d "," -f2)
  local submodule_name=$(basename $submodule_folder)
  local project_last_commit_id=$(git -C $project_folder rev-parse HEAD)
  local submodule_last_commit_id=$(git -C $project_folder/$submodule_name rev-parse HEAD)

  local dest_all_depth0=$TMPDIR/destination_all_depth0

  get_uri_with_submodules_all \
  "file://"$project_folder 0 $dest_all_depth0 |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $dest_all_depth0 rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_all_depth0/$submodule_name rev-parse HEAD)" = $submodule_last_commit_id
  test "$(git -C $dest_all_depth0/$submodule_name rev-list --all --count)" \> 1

  local dest_one_depth0=$TMPDIR/destination_one_depth0

  get_uri_with_submodules_at_depth \
  "file://"$project_folder 0 $submodule_name $dest_one_depth0 |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $dest_one_depth0 rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_all_depth0/$submodule_name rev-parse HEAD)" = $submodule_last_commit_id
  test "$(git -C $dest_one_depth0/$submodule_name rev-list --all --count)" \> 1

  local dest_all_depth1=$TMPDIR/destination_all_depth1

  get_uri_with_submodules_all \
  "file://"$project_folder 1 $dest_all_depth1 |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $dest_all_depth1 rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_all_depth1/$submodule_name rev-parse HEAD)" = $submodule_last_commit_id
  test "$(git -C $dest_all_depth1/$submodule_name rev-list --all --count)" = 1

  local dest_one_depth1=$TMPDIR/destination_one_depth1

  get_uri_with_submodules_at_depth \
  "file://"$project_folder 1 $submodule_name $dest_one_depth1 |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $dest_one_depth1 rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_all_depth1/$submodule_name rev-parse HEAD)" = $submodule_last_commit_id
  test "$(git -C $dest_one_depth1/$submodule_name rev-list --all --count)" = 1
}

it_falls_back_to_deep_clone_of_submodule_if_ref_not_found() {
  local repo_with_submodule_info=$(init_repo_with_submodule)
  local main_repo=${repo_with_submodule_info%,*}
  local submodule_repo=${repo_with_submodule_info#*,}
  local submodule_name=${submodule_repo##*/}
  local main_repo_last_commit_id=$(git -C $main_repo rev-parse HEAD)
  local submodule_repo_last_commit_id=$(git -C $submodule_repo rev-parse HEAD)

  # 128 is the threshold when it starts doing a deep clone
  for (( i = 0; i < 128; i++ )); do
    make_commit $submodule_repo >/dev/null
  done

  local dest=$TMPDIR/destination

  ( \
    get_uri_with_submodules_all \
      "file://$main_repo" 1 $dest 3>&2- 2>&1- 1>&3- 3>&- \
        | tee $TMPDIR/stderr \
  ) 3>&1- 1>&2- 2>&3- 3>&- | jq -e "
    .version == {ref: $(echo $main_repo_last_commit_id | jq -R .)}
  "

  test "$(git -C $main_repo rev-parse HEAD)" = $main_repo_last_commit_id

  echo "testing for msg 1" >&2
  for d in 1 2 4 8 16 32 64 128; do
    grep "Could not find ref ${submodule_repo_last_commit_id} in a shallow clone of depth ${d}" <$TMPDIR/stderr
  done
  echo "test for msg 1 done" >&2

  for d in 2 4 8 16 32 64 128; do
    grep "Deepening the shallow clone to depth ${d}..." <$TMPDIR/stderr
  done

  grep "Reached depth threshold 128, falling back to deep clone..." <$TMPDIR/stderr
}

it_fails_if_the_ref_cannot_be_found_while_deepening_a_submodule() {
  local repo_with_submodule_info=$(init_repo_with_submodule)
  local main_repo=${repo_with_submodule_info%,*}
  local submodule_repo=${repo_with_submodule_info#*,}
  local submodule_name=${submodule_repo##*/}
  local submodule_last_commit_id=$(git -C "$submodule_repo" rev-parse HEAD)

  git -C "$submodule_repo" reset --hard HEAD^ >/dev/null

  local dest=$TMPDIR/destination

  output=$(get_uri_with_submodules_all "file://$main_repo" 1 $dest 2>&1) \
    && exit_code=$? || exit_code=$?

  echo $output $exit_code
  test "${exit_code}" \!= 0
  echo "${output}" | grep "Reached max depth of the origin repo while deepening the shallow clone, it's a deep clone now"
  echo "${output}" | grep "fatal: reference is not a tree: $submodule_last_commit_id"
}

# the submodule incremental deepening depends on overwriting the update method
# of the submodule, so we should test if it's properly restored
it_preserves_the_submodule_update_method() {
  local repo_with_submodule_info=$(init_repo_with_submodule)
  local main_repo=${repo_with_submodule_info%,*}
  local submodule_repo=${repo_with_submodule_info#*,}
  local submodule_name=${submodule_repo##*/}
  local main_repo_last_commit_id=$(git -C $main_repo rev-parse HEAD)

  local dest=$TMPDIR/destination

  get_uri_with_submodules_all "file://$main_repo" 1 $dest | jq -e "
    .version == {ref: $(echo $main_repo_last_commit_id | jq -R .)}
  "

  # "git config ..." returns false if the key is not found (unset)
  ! git -C "$dest" config "submodule.${submodule_name}.update"


  rm -rf "$dest"


  git -C "$main_repo" config --file .gitmodules --replace-all "submodule.${submodule_name}.update" merge
  git -C "$main_repo" add .gitmodules
  git -C "$main_repo" commit -m 'Add .gitmodules' >/dev/null

  local main_repo_last_commit_id=$(git -C $main_repo rev-parse HEAD)
  local submodule_repo_last_commit_id=$(git -C $submodule_repo rev-parse HEAD)

  get_uri_with_submodules_all "file://$main_repo" 1 $dest | jq -e "
    .version == {ref: $(echo $main_repo_last_commit_id | jq -R .)}
  "

  test "$(git -C "$dest" config "submodule.${submodule_name}.update")" == "merge"
}

it_honors_the_parameter_flags_for_submodules() {
  local repo_info=$(init_repo_with_submodule_of_nested_submodule)
  local project_folder=$(echo $repo_info | cut -d "," -f1)
  local submodule_folder=$(echo $repo_info | cut -d "," -f2)
  local submodule_name=$(basename $submodule_folder)
  local subsubmodule_folder=$(echo $repo_info | cut -d "," -f3)
  local subsubmodule_name=$(basename $subsubmodule_folder)
  local project_last_commit_id=$(git -C $project_folder rev-parse HEAD)

  echo $project_folder
  echo $submodule_name
  echo $subsubmodule_name

  # testing: recursive explicit enabled
  local dest_recursive_true=$TMPDIR/recursive_true
  get_uri_with_submodules_and_parameter_recursive \
  "file://"$project_folder 1 "all" true $dest_recursive_true |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "
  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_recursive_true/$submodule_name rev-list --all --count)" = 1
  test "$(git -C $dest_recursive_true/$submodule_name/$subsubmodule_name rev-list --all --count)" = 1

  # recursive explicit disabled
  local dest_recursive_false=$TMPDIR/recursive_false
  get_uri_with_submodules_and_parameter_recursive \
  "file://"$project_folder 1 "all" false $dest_recursive_false |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "
  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_recursive_false/$submodule_name rev-list --all --count)" = 1
  test "$(ls $dest_recursive_false/$submodule_name/$subsubmodule_name | wc -l)" = 0

  # remote explicit enabled
  local dest_remote_true=$TMPDIR/remote_true
  get_uri_with_submodules_and_parameter_remote \
  "file://"$project_folder 1 "all" true $dest_remote_true |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "
  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_remote_true/$submodule_name rev-list --all --count)" = 1
  test "$(git -C $dest_remote_true/$submodule_name/$subsubmodule_name rev-list --all --count)" = 1

  # remote explicit disabled
  local dest_remote_false=$TMPDIR/remote_false
  get_uri_with_submodules_and_parameter_remote \
  "file://"$project_folder 1 "all" false $dest_remote_false |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "
  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_remote_false/$submodule_name rev-list --all --count)" = 1
  test "$(git -C $dest_remote_false/$submodule_name/$subsubmodule_name rev-list --all --count)" = 1
}

it_can_get_and_set_git_config() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  cp ~/.gitconfig ~/.gitconfig.orig

  get_uri_with_config $repo $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test "$(git config --global core.pager)" == 'true'
  test "$(git config --global credential.helper)" == '!true long command with variables $@'

  mv ~/.gitconfig.orig ~/.gitconfig
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

it_cant_get_commit_with_invalid_key() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  set +e
  output=$(get_uri_with_invalid_verification_key $repo $dest 2>&1)
  exit_code=$?
  set -e

  test "${exit_code}" == 2
  echo "${output}" | grep "Invalid GPG key in: abcd"
}

it_cant_get_commit_not_signed() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  set +e
  output=$(get_uri_with_verification_key $repo $dest 2>&1)
  exit_code=$?
  set -e

  test "${exit_code}" == 1
  echo "${output}" | grep "The commit ${ref} is not signed"
}

it_can_get_signed_commit() {
  local repo=$(gpg_fixture_repo_path)
  local ref=$(fetch_head_ref $repo)
  test "$ref" != ""
  local dest=$TMPDIR/destination

  get_uri_with_verification_key $repo $dest

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref
}

it_can_get_signed_commit_via_tag() {
  local repo=$(gpg_fixture_repo_path)
  local commit=$(fetch_head_ref $repo)
  local ref=$(make_annotated_tag $repo 'test-0.0.1' 'a message')
  local dest=$TMPDIR/destination

  get_uri_with_verification_key_and_tag_filter $repo $dest 'test-*' $ref

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $commit
}

it_cant_get_commit_signed_with_unknown_key() {
  local repo=$(gpg_fixture_repo_path)
  local ref=$(fetch_head_ref $repo)
  test "$ref" != ""
  local dest=$TMPDIR/destination

  set +e
  output=$(get_uri_with_unknown_verification_key $repo $dest 2>&1)
  exit_code=$?
  set -e

  test "${exit_code}" = 1
  echo "${output}" | grep "gpg: Can't check signature: No public key"
}

it_cant_get_signed_commit_when_using_keyserver_and_bogus_key() {
  local repo=$(gpg_fixture_repo_path)
  local ref=$(fetch_head_ref $repo)
  test "$ref" != ""
  local dest=$TMPDIR/destination

  set +e
  output=$(get_uri_when_using_keyserver_and_bogus_key $repo $dest 2>&1)
  exit_code=$?
  set -e

  test "${exit_code}" = 123
  echo "${output}" | grep "gpg: \"abcd\" not a key ID: skipping"
}

it_cant_get_signed_commit_when_using_keyserver_and_unknown_key_id() {
  local repo=$(gpg_fixture_repo_path)
  local ref=$(fetch_head_ref $repo)
  test "$ref" != ""
  local dest=$TMPDIR/destination

  set +e
  output=$(get_uri_when_using_keyserver_and_unknown_key $repo $dest 2>&1)
  exit_code=$?
  set -e

  echo $output $exit_code
  test "${exit_code}" = 123
  echo "${output}" | grep "gpg: keyserver receive failed" # removed the "No data" because it would not consistently return that copy (network issues?)
}

it_can_get_signed_commit_when_using_keyserver() {
  local repo=$(gpg_fixture_repo_path)
  local ref=$(fetch_head_ref $repo)
  test "$ref" != ""
  local dest=$TMPDIR/destination

  get_uri_when_using_keyserver $repo $dest

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref
}

it_can_get_committer_email() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination
  local committer_email="test@example.com"

  get_uri $repo $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test -e $dest/.git/committer || \
    ( echo ".git/committer does not exist."; return 1 )
  test "$(cat $dest/.git/committer)" = $committer_email || \
    ( echo "Committer email not found."; return 1 )
}

it_can_get_returned_ref() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

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
  test -e $dest/.git/ref || ( echo ".git/ref does not exist."; return 1 )
  test "$(cat $dest/.git/ref)" = "${ref1}" || \
    ( echo ".git/ref does not match. Expected '${ref1}', got '$(cat $dest/.git/ref)'"; return 1 )

  rm -rf $TMPDIR/destination
  get_uri_at_ref $repo $ref2 $TMPDIR/destination | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "
  test -e $dest/.git/ref || ( echo ".git/ref does not exist."; return 1 )
  test "$(cat $dest/.git/ref)" = "${ref2}" || \
    ( echo ".git/ref does not match. Expected '${ref2}', got '$(cat $dest/.git/ref)'"; return 1 )

  rm -rf $TMPDIR/destination
  get_uri_at_ref $repo $ref3 $TMPDIR/destination | jq -e "
    .version == {ref: $(echo $ref3 | jq -R .)}
  "
  test -e $dest/.git/ref || ( echo ".git/ref does not exist."; return 1 )
  test "$(cat $dest/.git/ref)" = "${ref3}" || \
    ( echo ".git/ref does not match. Expected '${ref3}', got '$(cat $dest/.git/ref)'"; return 1 )

  test -e $dest/.git/short_ref || ( echo ".git/short_ref does not exist."; return 1 )
  local expected_short_ref="test-$(echo ${ref3} | cut -c1-7)"
  test "$(cat $dest/.git/short_ref)" = $expected_short_ref || \
    ( echo ".git/short_ref does not match. Expected '${expected_short_ref}', got '$(cat $dest/.git/short_ref)'"; return 1 )
}

it_can_get_commit_message() {
  local repo=$(init_repo)
  local commit_message='Awesome-commit-message'
  local ref=$(make_commit $repo $commit_message)
  local dest=$TMPDIR/destination
  local expected_content="commit 1 $repo/some-file $commit_message"

  get_uri $repo $dest

  test -e $dest/.git/commit_message || \
    ( echo ".git/commit_message does not exist."; return 1 )
  test "$(cat $dest/.git/commit_message)" = "$expected_content" || \
    ( echo "Commit message does not match."; return 1 )
}

it_decrypts_git_crypted_files() {
  local repo=$(git_crypt_fixture_repo_path)
  local dest=$TMPDIR/destination

  get_uri_with_git_crypt_key $repo $dest

  test $(cat $dest/secrets.txt) = "secret" || \
    ( echo "encrypted file was not decrypted"; return 1 )
}

it_clears_tags_with_clean_tags_param() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  git -C $repo tag v1.1-pre

  local dest=$TMPDIR/destination

  get_uri_with_clean_tags $repo $dest "true"

  test -z "$(git -C $dest tag)"
}

it_retains_tags_by_default() {
  local tag="v1.1-pre"
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  git -C $repo tag $tag

  local dest=$TMPDIR/destination

  get_uri $repo $dest

  test "$(git -C $dest tag)" == $tag
}

it_retains_tags_with_clean_tags_param() {
  local tag="v1.1-pre"
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  git -C $repo tag $tag

  local dest=$TMPDIR/destination

  get_uri_with_clean_tags $repo $dest "false"

  test "$(git -C $dest tag)" == $tag
}

run it_can_get_from_url
run it_can_get_from_url_at_ref
run it_can_get_from_url_at_branch
run it_can_get_from_url_only_single_branch
run it_omits_empty_branch_in_metadata
run it_returns_branch_in_metadata
run it_omits_empty_tags_in_metadata
run it_returns_list_of_tags_in_metadata
run it_can_use_submodules_without_perl_warning
run it_honors_the_depth_flag
run it_can_get_from_url_at_depth_at_ref
run it_falls_back_to_deep_clone_if_ref_not_found
run it_does_not_enter_an_infinite_loop_if_the_ref_cannot_be_found_and_depth_is_set
run it_honors_the_depth_flag_for_submodules
run it_falls_back_to_deep_clone_of_submodule_if_ref_not_found
run it_fails_if_the_ref_cannot_be_found_while_deepening_a_submodule
run it_preserves_the_submodule_update_method
run it_honors_the_parameter_flags_for_submodules
run it_can_get_and_set_git_config
run it_returns_same_ref
run it_cant_get_commit_with_invalid_key
run it_cant_get_commit_not_signed
run it_can_get_signed_commit
run it_cant_get_commit_signed_with_unknown_key
run it_cant_get_signed_commit_when_using_keyserver_and_bogus_key
run it_cant_get_signed_commit_when_using_keyserver_and_unknown_key_id
run it_can_get_signed_commit_when_using_keyserver
run it_can_get_signed_commit_via_tag
run it_can_get_committer_email
run it_can_get_returned_ref
run it_can_get_commit_message
run it_decrypts_git_crypted_files
run it_clears_tags_with_clean_tags_param
run it_retains_tags_by_default
run it_retains_tags_with_clean_tags_param
