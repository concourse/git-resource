#!/bin/bash

set -e

source $(dirname $0)/helpers.sh
source /opt/resource/common.sh

it_has_no_url_in_metadata_when_remote_is_not_configured() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    cd $repo

    local metadata=$(git_metadata)
    test $(echo $metadata | jq '. | map(select(.name == "url")) | length') = "0"
}

it_has_no_url_in_metadata_when_remote_is_not_github() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    cd $repo

    # set a bitbucket origin
    git remote add origin git@bitbucket.com:someOrg/someRepo.git

    local metadata=$(git_metadata)
    test $(echo $metadata | jq '. | map(select(.name == "url")) | length') = "0"
}

it_has_url_in_metadata_when_remote_is_private_github() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    cd $repo

    # set a github origin
    git remote add origin git@github.com:concourse/git-resource.git

    local metadata=$(git_metadata)
    test $(echo $metadata | jq '. | map(select(.name == "url")) | length') = "1"
}

it_has_url_in_metadata_when_remote_is_public_github() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    cd $repo

    # set a github origin
    git remote add origin https://github.com/concourse/git-resource.git

    local metadata=$(git_metadata)
    test $(echo $metadata | jq '. | map(select(.name == "url")) | length') = "1"
}


run it_has_no_url_in_metadata_when_remote_is_not_configured
run it_has_no_url_in_metadata_when_remote_is_not_github
run it_has_url_in_metadata_when_remote_is_private_github
run it_has_url_in_metadata_when_remote_is_public_github
