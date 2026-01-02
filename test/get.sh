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

it_can_fetch_branches_that_already_exist() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)

  local dest=$TMPDIR/destination

  get_uri_with_fetch_branches $repo "master" $dest | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "
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

it_can_get_from_url_at_override_branch() {
  local repo=$(init_repo)
  local branch="branch-a"
  local ref=$(make_commit_to_branch $repo $branch)
  local dest=$TMPDIR/destination

  get_uri_with_override_branch $repo $branch $ref $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref
}

it_preserves_git_config_in_local_repository() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  # Save original gitconfig and set up minimal config for the test
  cp ~/.gitconfig ~/.gitconfig.bak 2>/dev/null || true
  cat > ~/.gitconfig <<EOF
[user]
	name = test
	email = test@example.com
EOF

  get_uri_with_config $repo $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # Verify configs are set in LOCAL repository (not global)
  test "$(git -C $dest config --local core.pager)" = "true" || \
    ( echo "Local git config core.pager not set"; return 1 )
  test "$(git -C $dest config --local credential.helper)" = '!true long command with variables $@' || \
    ( echo "Local git config credential.helper not set"; return 1 )

  # Verify they're actually in .git/config file
  grep -q "pager = true" $dest/.git/config || \
    ( echo "core.pager not found in .git/config"; return 1 )
  grep -q 'helper = !true long command with variables $@' $dest/.git/config || \
    ( echo "credential.helper not found in .git/config"; return 1 )

  # Restore original gitconfig
  mv ~/.gitconfig.bak ~/.gitconfig 2>/dev/null || true
}

it_can_get_from_url_with_sparse_paths() {
   local repo=$(init_repo)
   local ref1=$(make_commit_to_file $repo file-a)
   local ref2=$(make_commit_to_file $repo file-b)
   local dest=$TMPDIR/destination
   local sparse_paths="file-a"

   get_uri_with_sparse $repo $dest $sparse_paths | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "

  test -e $dest/file-a
  test ! -e $dest/file-b

  test "$(git -C $dest rev-parse HEAD)" = $ref2
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

it_writes_complete_metadata_files() {
  local repo=$(init_repo)

  # Create a commit with specific author/committer info
  git -C $repo \
    -c user.name='alice' \
    -c user.email='alice@example.com' \
    commit --allow-empty -m "test commit message"
  local ref=$(git -C $repo rev-parse HEAD)

  # Add multiple tags to test tag aggregation
  git -C $repo tag v1.0.0
  git -C $repo tag v1.0.0-rc1
  git -C $repo tag latest

  local dest=$TMPDIR/destination
  get_uri $repo $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # === Verify metadata.json ===
  test -e $dest/.git/metadata.json || \
    ( echo ".git/metadata.json does not exist"; return 1 )

  cat $dest/.git/metadata.json | jq -e '. | length > 0' > /dev/null || \
    ( echo ".git/metadata.json is not valid JSON or is empty"; return 1 )

  # === Verify all metadata files ===

  # .git/commit
  test -e $dest/.git/commit || \
    ( echo ".git/commit does not exist"; return 1 )
  test "$(cat $dest/.git/commit)" = "$ref" || \
    ( echo ".git/commit content mismatch"; return 1 )

  # .git/author
  test -e $dest/.git/author || \
    ( echo ".git/author does not exist"; return 1 )
  test "$(cat $dest/.git/author)" = "alice" || \
    ( echo ".git/author content mismatch"; return 1 )

  # .git/author_date
  test -e $dest/.git/author_date || \
    ( echo ".git/author_date does not exist"; return 1 )
  echo "$(cat $dest/.git/author_date)" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}$" || \
    ( echo ".git/author_date format invalid: $(cat $dest/.git/author_date)"; return 1 )

  # .git/committer
  test -e $dest/.git/committer || \
    ( echo ".git/committer does not exist"; return 1 )
  test "$(cat $dest/.git/committer)" = "alice@example.com" || \
    ( echo ".git/committer content mismatch"; return 1 )

  # .git/committer_name
  test -e $dest/.git/committer_name || \
    ( echo ".git/committer_name does not exist"; return 1 )
  test "$(cat $dest/.git/committer_name)" = "alice" || \
    ( echo ".git/committer_name content mismatch"; return 1 )

  # .git/committer_date
  test -e $dest/.git/committer_date || \
    ( echo ".git/committer_date does not exist"; return 1 )
  echo "$(cat $dest/.git/committer_date)" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}$" || \
    ( echo ".git/committer_date format invalid"; return 1 )

  # .git/ref
  test -e $dest/.git/ref || \
    ( echo ".git/ref does not exist"; return 1 )
  test "$(cat $dest/.git/ref)" = "$ref" || \
    ( echo ".git/ref content mismatch"; return 1 )

  # .git/branch
  test -e $dest/.git/branch || \
    ( echo ".git/branch does not exist"; return 1 )
  test "$(cat $dest/.git/branch)" = "master" || \
    ( echo ".git/branch content mismatch"; return 1 )

  # .git/short_ref
  test -e $dest/.git/short_ref || \
    ( echo ".git/short_ref does not exist"; return 1 )
  local expected_short="test-$(echo $ref | cut -c1-7)"
  test "$(cat $dest/.git/short_ref)" = "$expected_short" || \
    ( echo ".git/short_ref content mismatch"; return 1 )

  # .git/commit_message
  test -e $dest/.git/commit_message || \
    ( echo ".git/commit_message does not exist"; return 1 )
  grep -q "test commit message" $dest/.git/commit_message || \
    ( echo ".git/commit_message content mismatch"; return 1 )

  # .git/commit_timestamp
  test -e $dest/.git/commit_timestamp || \
    ( echo ".git/commit_timestamp does not exist"; return 1 )
  test -n "$(cat $dest/.git/commit_timestamp)" || \
    ( echo ".git/commit_timestamp is empty"; return 1 )

  # .git/describe_ref
  test -e $dest/.git/describe_ref || \
    ( echo ".git/describe_ref does not exist"; return 1 )

  # .git/tags
  test -e $dest/.git/tags || \
    ( echo ".git/tags does not exist"; return 1 )
  local tags=$(cat $dest/.git/tags)
  test -n "$tags" || \
    ( echo ".git/tags is empty when tags exist"; return 1 )
  echo "$tags" | grep -q "v1.0.0" || \
    ( echo ".git/tags missing v1.0.0"; return 1 )
  echo "$tags" | grep -q "v1.0.0-rc1" || \
    ( echo ".git/tags missing v1.0.0-rc1"; return 1 )
  echo "$tags" | grep -q "latest" || \
    ( echo ".git/tags missing latest"; return 1 )

  # .git/url
  test -e $dest/.git/url || \
    ( echo ".git/url does not exist"; return 1 )
  test -z "$(cat $dest/.git/url)" || \
    ( echo ".git/url should be empty for local repo"; return 1 )

  # === Test edge case: no tags ===
  rm -rf $dest
  local repo_notags=$(init_repo)
  local ref_notags=$(make_commit $repo_notags)
  get_uri $repo_notags $dest

  test -e $dest/.git/tags || \
    ( echo ".git/tags does not exist when no tags present"; return 1 )
  test -z "$(cat $dest/.git/tags)" || \
    ( echo ".git/tags should be empty when no tags exist"; return 1 )

  # === Verify metadata.json structure ===
  local has_commit=$(cat $dest/.git/metadata.json | jq '[.[] | select(.name == "commit")] | length')
  test "$has_commit" = "1" || \
    ( echo "metadata.json missing commit field"; return 1 )

  local has_author=$(cat $dest/.git/metadata.json | jq '[.[] | select(.name == "author")] | length')
  test "$has_author" = "1" || \
    ( echo "metadata.json missing author field"; return 1 )
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

  # 127 is the threshold when it starts doing a deep clone
  for (( i = 0; i < 127; i++ )); do
    make_commit $repo >/dev/null
  done

  local dest=$TMPDIR/destination

  ( get_uri_at_depth_at_ref "file://$repo" 1 $ref1 $dest 3>&2- 2>&1- 1>&3- 3>&- | tee $TMPDIR/stderr ) 3>&1- 1>&2- 2>&3- 3>&- | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  echo "testing for msg 1" >&2
  for d in 1 3 7 15 31 63 127; do
    grep "Could not find ref ${ref1}~0 in a shallow clone of depth ${d}" <$TMPDIR/stderr
  done
  echo "test for msg 1 done" >&2

  for d in 2 4 8 16 32 64; do
    grep "Deepening the shallow clone by an additional ${d}..." <$TMPDIR/stderr
  done

  grep "Reached depth threshold 127, falling back to deep clone..." <$TMPDIR/stderr
}

it_considers_depth_if_ref_not_found() {
  local repo=$(init_repo)
  local depth=3

  # make commits we're interested
  local ref0=$(make_commit $repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)
  local ref3=$(make_commit $repo)

  # make a total of 22 commits, so that ref0 is never fetched
  for (( i = 0; i < 18; i++ )); do
    make_commit $repo >/dev/null
  done

  local dest=$TMPDIR/destination

  ( get_uri_at_depth_at_ref "file://$repo" $depth $ref3 $dest 3>&2- 2>&1- 1>&3- 3>&- | tee $TMPDIR/stderr ) 3>&1- 1>&2- 2>&3- 3>&- | jq -e "
    .version == {ref: $(echo $ref3 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref3
  test "$(git -C $dest rev-parse HEAD~1)" = $ref2
  test "$(git -C $dest rev-parse HEAD~2)" = $ref1
  test -e "$dest/.git/shallow" # it's still shallow

  echo "testing for 'could not find' messages'" >&2
  for d in 3 9; do
    grep "Could not find ref ${ref3}~2 in a shallow clone of depth ${d}" <$TMPDIR/stderr
  done
  echo "testing for 'could not find' messages done" >&2

  echo "testing for 'deepening' messages'" >&2
  for d in 6 12; do
    grep "Deepening the shallow clone by an additional ${d}..." <$TMPDIR/stderr
  done
  echo "testing for 'deepening' messages' done" >&2
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
  echo "${output}" | grep "fatal: unable to read tree (${ref2})"
}

it_can_use_submodules_with_names_that_arent_paths() {
  local repo_and_submodule=$(init_repo_with_named_submodule some-name some-path)

  local repo=$(echo $repo_and_submodule | cut -d, -f1)
  local ref=$(make_commit $repo)

  local submodule=$(echo $repo_and_submodule | cut -d, -f2)
  local submodule_ref=$(git -C $submodule rev-parse HEAD)

  local dest=$TMPDIR/destination

  get_uri_with_submodules_all "file://"$repo 1 $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test "$(git -C $dest rev-parse HEAD)" = $ref
  test "$(git -C $dest/some-path rev-parse HEAD)" = $submodule_ref
}

it_can_use_submodules_with_missing_paths() {
  local repo_and_submodule=$(init_repo_with_submodule_missing_path some-name some-path)

  local repo=$(echo $repo_and_submodule | cut -d, -f1)
  local ref=$(make_commit $repo)

  local submodule=$(echo $repo_and_submodule | cut -d, -f2)
  local submodule_ref=$(git -C $submodule rev-parse HEAD)

  local dest=$TMPDIR/destination

  get_uri_with_submodules_all "file://"$repo 1 $dest | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test "$(git -C $dest rev-parse HEAD)" = $ref
  test ! -e $dest/some-path
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

  # 127 is the threshold when it starts doing a deep clone
  for (( i = 0; i < 127; i++ )); do
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

  echo "testing for 'could not find' messages'" >&2
  for d in 1 3 7 15 31 63 127; do
    grep "Could not find ref ${submodule_repo_last_commit_id}~0 in a shallow clone of depth ${d}" <$TMPDIR/stderr
  done
  echo "testing for 'could not find' messages done" >&2

  echo "testing for 'deepening' messages'" >&2
  for d in 2 4 8 16 32 64; do
    grep "Deepening the shallow clone by an additional ${d}..." <$TMPDIR/stderr
  done
  echo "testing for 'deepening' messages' done" >&2

  echo "testing for 'reached threshold' message'" >&2
  grep "Reached depth threshold 127, falling back to deep clone..." <$TMPDIR/stderr
  echo "testing for 'reached threshold' message done'" >&2
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
  echo "${output}" | grep "fatal: unable to read tree (${submodule_last_commit_id})"
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

it_can_get_signed_commit_via_tag_regex() {
  local repo=$(gpg_fixture_repo_path)
  local commit=$(fetch_head_ref $repo)
  local ref=$(make_annotated_tag $repo 'test2-0.0.1' 'a message')
  local dest=$TMPDIR/destination

  get_uri_with_verification_key_and_tag_regex $repo $dest 'test2-.*' $ref

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

  test -e $dest/.git/describe_ref || ( echo ".git/describe_ref does not exist."; return 1 )
  local expected_describe_ref="0.9-production"
  test "$(cat $dest/.git/describe_ref)" = $expected_describe_ref || \
    ( echo ".git/describe_ref does not match. Expected '${expected_describe_ref}', got '$(cat $dest/.git/describe_ref)'"; return 1 )
}

it_can_get_commit_branch() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_commit $repo)
  local ref3=$(make_annotated_tag $repo "v1.1" "tag 1")

  local dest=$TMPDIR/destination

  get_uri $repo $dest

  test -e $dest/.git/branch || ( echo ".git/branch does not exist."; return 1 )
  test "$(cat $dest/.git/branch)" = "master" || \
    ( echo ".git/branch does not match. Expected 'master', got '$(cat $dest/.git/branch)'"; return 1 )

  rm -rf $dest

  get_uri_at_branch $repo branch-a $dest

  test -e $dest/.git/branch || ( echo ".git/branch does not exist."; return 1 )
  test "$(cat $dest/.git/branch)" = "branch-a" || \
    ( echo ".git/branch does not match. Expected 'branch-a', got '$(cat $dest/.git/branch)'"; return 1 )
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

it_can_get_commit_timestamps() {
  run test_commit_timestamp_format "iso8601"
  run test_commit_timestamp_format "iso-strict"
  run test_commit_timestamp_format "rfc"
  run test_commit_timestamp_format "short"
  run test_commit_timestamp_format "raw"
  run test_commit_timestamp_format "unix"
}

test_commit_timestamp_format() {
  local repo=$(init_repo)
  local commit_message='Time-is-relevant!'
  local ref=$(make_commit $repo $commit_message)
  local dest=$TMPDIR/destination

  get_uri_with_custom_timestamp $repo $dest $1

  pushd $dest
  local expected_timestamp=$(git log -1 --date=$1 --format=format:%cd)
  popd

  test -e $dest/.git/commit_timestamp || ( echo ".git/commit_timestamp does not exist."; return 1 )
  test "$(cat $dest/.git/commit_timestamp)" = "$expected_timestamp" || \
    ( echo "Commit timestamp for format $1 differs from expectation."; return 1 )
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

it_returns_list_without_tags_in_metadata() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)

  local ref2=$(make_annotated_tag $repo "v1.1-pre" "tag 1")
  local ref3=$(make_annotated_tag $repo "v1.1-final" "tag 2")

  local dest=$TMPDIR/destination
  get_uri_at_branch_without_fetch_tags $repo branch-a $dest | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
    and
    (.metadata | .[] | select(.name != \"tags\"))
  "
}

it_returns_list_of_all_tags_in_metadata() {

  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_annotated_tag $repo "v1.1-pre" "tag 1")
  local ref3=$(make_annotated_tag $repo "v1.1-final" "tag 2")
  local ref4=$(make_commit_to_branch $repo branch-b)
  local ref5=$(make_annotated_tag $repo "v1.1-branch-b" "tag 3")

  local dest=$TMPDIR/destination
  get_uri_at_branch_with_fetch_tags $repo branch-a $dest | jq -e "
    .version == {ref: $(echo $ref4 | jq -R .)}
    and
    (.metadata | .[] | select(.name == \"tags\") | .value == \"v1.1-branch-b,v1.1-final,v1.1-pre\")
  "
}

it_can_get_from_url_at_branch_with_search_remote_refs() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_commit_to_branch $repo branch-a)
  git -C $repo update-ref refs/heads/branch-a $ref1
  git -C $repo update-ref refs/changes/1 $ref2
  git -C $repo log --all --oneline
  git -C $repo branch -v
  local dest=$TMPDIR/destination

  # use file:// repo to force the regular git transport instead of local copying
  set +e
  output=$(get_uri_at_branch_with_ref file://$repo "branch-a" $ref2 $dest 2>&1)
  exit_code=$?
  set -e

  echo $output $exit_code
  test "${exit_code}" = 128
  echo "$output" | grep "fatal: unable to read tree ("
  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" != $ref2

  rm -rf $dest

  get_uri_at_branch_with_search_remote_refs file://$repo "branch-a" $ref2 $dest | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2
}

it_errors_when_there_are_unknown_keys_in_params() {
    local failed_output=$TMPDIR/get-unknown-keys-output
    if get_uri_unknown_keys "some-uri" "some-dest" 2>"$failed_output"; then
        echo "get should have failed"
        return 1
    fi

    grep "Found unknown keys in get params:" "$failed_output"
    grep "unknown_key" "$failed_output"
    grep "other_key" "$failed_output"
}

run it_can_use_submodules_with_missing_paths
run it_can_use_submodules_with_names_that_arent_paths
run it_can_use_submodules_without_perl_warning
run it_honors_the_depth_flag_for_submodules
run it_falls_back_to_deep_clone_of_submodule_if_ref_not_found
run it_fails_if_the_ref_cannot_be_found_while_deepening_a_submodule
run it_honors_the_parameter_flags_for_submodules
run it_can_fetch_branches_that_already_exist
run it_can_get_from_url
run it_can_get_from_url_at_ref
run it_can_get_from_url_at_branch
run it_can_get_from_url_only_single_branch
run it_can_get_from_url_at_override_branch
run it_preserves_git_config_in_local_repository
run it_can_get_from_url_with_sparse_paths
run it_omits_empty_branch_in_metadata
run it_returns_branch_in_metadata
run it_omits_empty_tags_in_metadata
run it_returns_list_of_tags_in_metadata
run it_writes_complete_metadata_files
run it_honors_the_depth_flag
run it_can_get_from_url_at_depth_at_ref
run it_falls_back_to_deep_clone_if_ref_not_found
run it_considers_depth_if_ref_not_found
run it_does_not_enter_an_infinite_loop_if_the_ref_cannot_be_found_and_depth_is_set
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
run it_can_get_signed_commit_via_tag_regex
run it_can_get_committer_email
run it_can_get_returned_ref
run it_can_get_commit_branch
run it_can_get_commit_message
run it_can_get_commit_timestamps
run it_decrypts_git_crypted_files
run it_clears_tags_with_clean_tags_param
run it_retains_tags_by_default
run it_retains_tags_with_clean_tags_param
run it_returns_list_without_tags_in_metadata
run it_returns_list_of_all_tags_in_metadata
run it_can_get_from_url_at_branch_with_search_remote_refs
run it_errors_when_there_are_unknown_keys_in_params
