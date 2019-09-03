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

it_has_no_url_in_metadata_when_remote_is_not_github() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")

    # set a bitbucket origin
    cd $repo
    git remote add origin git@bitbucket.com:someOrg/someRepo.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 0
}

it_has_url_in_metadata_when_remote_is_private_github() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com/concourse/git-resource/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin git@github.com:concourse/git-resource.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl

}

it_has_url_in_metadata_when_remote_is_public_github() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com/concourse/git-resource/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin https://github.com/concourse/git-resource.git

    test $(git_metadata | jq -r '. | map(select(.name == "url")) | length') = 1
    test $(git_metadata | jq -r '.[] | select(.name == "url") | .value') = $expectedUrl
}

run it_has_no_url_in_metadata_when_remote_is_not_configured
run it_has_no_url_in_metadata_when_remote_is_not_github
run it_has_url_in_metadata_when_remote_is_private_github
run it_has_url_in_metadata_when_remote_is_public_github
