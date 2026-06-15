#!/bin/bash

set -e

source $(dirname $0)/helpers.sh
source /opt/resource/common.sh

it_has_no_url_in_metadata_when_remote_is_not_configured() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    cd $repo

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 0
}

it_has_no_url_in_metadata_when_remote_is_not_known() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")

    # set an unrecognized origin
    cd $repo
    git remote add origin git@whoknows.com:some/path/repo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 0
}

it_has_url_in_metadata_when_remote_is_github_scp() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com/myorg/myrepo/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin git@github.com:myorg/myrepo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl

}

it_has_url_in_metadata_when_remote_is_github_ssh() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com/myorg/myrepo/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin ssh://git@github.com/myorg/myrepo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl
}

it_has_url_in_metadata_when_remote_is_github_ssh_over_443() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com:443/myorg/myrepo/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin ssh://git@github.com:443/myorg/myrepo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl
}

it_has_url_in_metadata_when_remote_is_github_https() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com/myorg/myrepo/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin https://github.com/myorg/myrepo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl
}

it_has_url_in_metadata_when_remote_is_likely_github_enterprise() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.company.com/myorg/myrepo/commit/$ref"

    # set a github enterprise origin
    cd $repo
    git remote add origin https://github.company.com/myorg/myrepo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl
}

it_has_url_in_metadata_when_remote_is_gitlab() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://gitlab.com/myorg/mygroup/myrepo/-/commit/$ref"

    # set a gitlab origin with nested groups
    cd $repo
    git remote add origin https://gitlab.com/myorg/mygroup/myrepo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl
}

it_has_url_in_metadata_when_remote_is_bitbucket() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://bitbucket.com/myteam/myrepo/commits/$ref"

    # set a bitbucket ssh origin
    cd $repo
    git remote add origin ssh://git@bitbucket.com/myteam/myrepo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl
}

# Invalid UTF-8 in a commit (or in a branch/tag name) must not break Concourse's
# gRPC metadata marshaling: "string field contains invalid UTF-8".
it_strips_invalid_utf8_from_metadata() {
    local repo=$(init_repo)
    make_commit_with_invalid_utf8 $repo >/dev/null
    git -C $repo branch "$(printf 'bad\xe9br')" HEAD
    git -C $repo tag "$(printf 'bad\xe9tag')" HEAD
    cd $repo

    # the fixture must actually be invalid UTF-8
    if git log -1 --format='%an%n%cn%n%B' | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then
        echo "fixture commit unexpectedly contains only valid UTF-8"
        return 1
    fi

    local metadata=$(git_metadata)

    printf '%s' "$metadata" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 || \
        ( echo "git_metadata emitted invalid UTF-8"; return 1 )

    # bad bytes must be dropped, not replaced with U+FFFD (which is what jq does)
    if printf '%s' "$metadata" | grep -q $'\xef\xbf\xbd'; then
        echo "metadata contains the U+FFFD replacement character"
        return 1
    fi

    test "$(echo "$metadata" | jq -r '.[] | select(.name == "author") | .value')" = "badname"
    test "$(echo "$metadata" | jq -r '.[] | select(.name == "committer") | .value')" = "badname"
    test "$(echo "$metadata" | jq -r '.[] | select(.name == "message") | .value')" = "badmessage"
    test "$(echo "$metadata" | jq -r '.[] | select(.name == "branch") | .value')" = "badbr,master"
    test "$(echo "$metadata" | jq -r '.[] | select(.name == "tags") | .value')" = "badtag"
    test "$(git_tag_metadata | jq -r '.[] | select(.name == "tag") | .value')" = "badtag"
}

it_truncates_large_messages() {
    local repo=$(init_repo)
    local message=$(cat /dev/urandom | tr -dc A-Z | head -c 20000 ; echo '')
    local ref=$(make_commit $repo $message)
    cd $repo

    test $(git_metadata | jq -r '.[] | select(.name == "message") | .value' | wc -m) = 10241
}


run it_has_no_url_in_metadata_when_remote_is_not_configured
run it_has_no_url_in_metadata_when_remote_is_not_known

run it_has_url_in_metadata_when_remote_is_github_scp
run it_has_url_in_metadata_when_remote_is_github_ssh
run it_has_url_in_metadata_when_remote_is_github_ssh_over_443
run it_has_url_in_metadata_when_remote_is_github_https
run it_has_url_in_metadata_when_remote_is_likely_github_enterprise

run it_has_url_in_metadata_when_remote_is_gitlab
run it_has_url_in_metadata_when_remote_is_bitbucket
run it_truncates_large_messages
run it_strips_invalid_utf8_from_metadata
