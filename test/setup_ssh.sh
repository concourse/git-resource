#!/bin/bash

set -e

# make host keys for sshd
ssh-keygen -A

# set up authorized keys for each user to be under that users .ssh dir
perl -p -i -e 's|AuthorizedKeysFile.*|AuthorizedKeysFile %h/.ssh/authorized_keys|' /etc/ssh/sshd_config

# start sshd with verbose logging
/usr/sbin/sshd -E /var/log/sshd -o 'LogLevel VERBOSE'

# ensure git executables on path
ln -s /usr/libexec/git-core/git-receive-pack /usr/bin/git-receive-pack
