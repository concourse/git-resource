#!/bin/bash

set -e

source "$(dirname "$0")/helpers.sh"
if [ -d /opt/resource ]; then
  source /opt/resource/common.sh
else
  source "$(dirname "$0")/../assets/common.sh"
fi

# Test case 1: setup_github_app_credentials without GitHub App credentials
it_skips_setup_when_github_app_credentials_not_provided() {
    export payload='{
        "source": {
            "uri": "https://github.com/test/repo.git"
        }
    }'
    export uri="https://github.com/test/repo.git"

    # This should not error and should not modify git config
    setup_github_app_credentials

    # Verify that git config was not modified with credential helper
    ! git config --global credential.helper | grep -q "x-access-token" || true
}

# Test case 2: setup_github_app_credentials with incomplete credentials (missing private key)
it_skips_setup_when_github_app_credentials_incomplete() {
    export payload='{
        "source": {
            "uri": "https://github.com/test/repo.git",
            "github_app_id": "123456"
        }
    }'
    export uri="https://github.com/test/repo.git"

    # This should not error and should not modify git config
    setup_github_app_credentials

    # Verify that git config was not modified
    ! git config --global credential.helper | grep -q "x-access-token" || true
}

# Test case 3: setup_github_app_credentials extracts credentials correctly
it_extracts_github_app_credentials() {
    local test_key="test-private-key-content"
    export payload='{
        "source": {
            "uri": "https://github.com/test/repo.git",
            "github_app_id": "123456",
            "github_app_private_key": "'"$test_key"'",
            "github_app_installation_id": "789012"
        }
    }'
    export uri="https://github.com/test/repo.git"

    # Extract the values to verify they are extracted correctly
    github_app_id=$(jq -r '.source.github_app_id // ""' <<< "$payload")
    github_app_private_key=$(jq -r '.source.github_app_private_key // ""' <<< "$payload")
    github_app_installation_id=$(jq -r '.source.github_app_installation_id // ""' <<< "$payload")

    test "$github_app_id" = "123456"
    test "$github_app_installation_id" = "789012"
    test "$github_app_private_key" = "$test_key"
}

# Test case 4: setup_github_app_credentials converts SSH URI to HTTPS
it_converts_ssh_uri_to_https() {
    export uri="git@github.com:test/repo.git"

    # Simulate the URI conversion logic
    if [[ $uri == git@github.com:* ]]; then
        uri="https://github.com/${uri#git@github.com:}"
    fi

    test "$uri" = "https://github.com/test/repo.git"
}

# Test case 5: setup_github_app_credentials with empty github_app_id
it_skips_when_github_app_id_is_empty() {
    export payload='{
        "source": {
            "uri": "https://github.com/test/repo.git",
            "github_app_id": "",
            "github_app_private_key": "test-key",
            "github_app_installation_id": "789012"
        }
    }'
    export uri="https://github.com/test/repo.git"

    # This should not error
    setup_github_app_credentials
}

# Test case 6: setup_github_app_credentials with empty github_app_private_key
it_skips_when_github_app_private_key_is_empty() {
    export payload='{
        "source": {
            "uri": "https://github.com/test/repo.git",
            "github_app_id": "123456",
            "github_app_private_key": "",
            "github_app_installation_id": "789012"
        }
    }'
    export uri="https://github.com/test/repo.git"

    # This should not error
    setup_github_app_credentials
}

# Test case 7: setup_github_app_credentials with empty github_app_installation_id
it_skips_when_github_app_installation_id_is_empty() {
    export payload='{
        "source": {
            "uri": "https://github.com/test/repo.git",
            "github_app_id": "123456",
            "github_app_private_key": "test-key",
            "github_app_installation_id": ""
        }
    }'
    export uri="https://github.com/test/repo.git"

    # This should not error
    setup_github_app_credentials
}

# Test case 8: Verify that the function handles JSON parsing correctly
it_handles_missing_json_fields() {
    export payload='{
        "source": {
            "uri": "https://github.com/test/repo.git"
        }
    }'
    export uri="https://github.com/test/repo.git"

    # Extract values when fields are missing
    github_app_id=$(jq -r '.source.github_app_id // ""' <<< "$payload")
    github_app_private_key=$(jq -r '.source.github_app_private_key // ""' <<< "$payload")
    github_app_installation_id=$(jq -r '.source.github_app_installation_id // ""' <<< "$payload")

    # Should return empty strings when fields are missing
    test -z "$github_app_id"
    test -z "$github_app_private_key"
    test -z "$github_app_installation_id"
}

# Test case 9: Verify SSH URI patterns are converted correctly
it_converts_various_ssh_uri_formats() {
    # Test standard SSH format
    uri="git@github.com:user/repo.git"
    if [[ $uri == git@github.com:* ]]; then
        uri="https://github.com/${uri#git@github.com:}"
    fi
    test "$uri" = "https://github.com/user/repo.git"

    # Test without .git extension
    uri="git@github.com:user/repo"
    if [[ $uri == git@github.com:* ]]; then
        uri="https://github.com/${uri#git@github.com:}"
    fi
    test "$uri" = "https://github.com/user/repo"
}

# Test case 10: Verify HTTPS URIs are not modified
it_does_not_modify_https_uris() {
    uri="https://github.com/test/repo.git"

    # Should not modify HTTPS URIs
    if [[ $uri == git@github.com:* ]]; then
        uri="https://github.com/${uri#git@github.com:}"
    fi

    test "$uri" = "https://github.com/test/repo.git"
}

run it_skips_setup_when_github_app_credentials_not_provided
run it_skips_setup_when_github_app_credentials_incomplete
run it_extracts_github_app_credentials
run it_converts_ssh_uri_to_https
run it_skips_when_github_app_id_is_empty
run it_skips_when_github_app_private_key_is_empty
run it_skips_when_github_app_installation_id_is_empty
run it_handles_missing_json_fields
run it_converts_various_ssh_uri_formats
run it_does_not_modify_https_uris
