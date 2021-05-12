#!/bin/bash
if [ -z "$GIT_SSH_PRIVATE_KEY_PASS" ]; then
    echo "Private key has a passphrase but private_key_passphrase has not been set." >&2
    exit 1
fi
echo "$GIT_SSH_PRIVATE_KEY_PASS"
