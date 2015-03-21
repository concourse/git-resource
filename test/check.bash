source $(dirname $0)/helpers.bash

function it_can_check_from_head() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  check_uri $repo | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "
}

function it_can_check_from_a_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)
  local ref3=$(make_commit $repo)

  check_uri_ref $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

function it_can_check_from_a_bogus_sha() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)

  check_uri_ref $repo "bogus-ref" | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "
}

with_tmpdir it_can_check_from_head
with_tmpdir it_can_check_from_a_ref
with_tmpdir it_can_check_from_a_bogus_sha
