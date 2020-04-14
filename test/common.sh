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
    local expectedUrl="https://gitlab.com/myorg/mygroup/myrepo/commit/$ref"

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

it_truncates_large_messages() {
    local repo=$(init_repo)
    local message=$(shuf -zer -n20000  {A..Z})
    local ref=$(make_commit $repo $message)
    cd $repo

    test $(git_metadata | jq -r '.[] | select(.name == "message") | .value' | wc -m) = 10240
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
