#!/bin/bash

set -e

# make host keys for sshd
ssh-keygen -A
# set up authorized keys for each user to be under that users .ssh dir
perl -p -i -e 's|AuthorizedKeysFile.*|AuthorizedKeysFile %h/.ssh/authorized_keys|' /etc/ssh/sshd_config
/usr/sbin/sshd -E /var/log/sshd -o 'LogLevel VERBOSE'

# ensure git executables on path
ln -s /usr/libexec/git-core/git-receive-pack /usr/bin/git-receive-pack



#ssh git@githost 'mkdir testsubmodule.git && cd testsubmodule.git && git init --bare'
#
#
#git clone git@githost:/home/git/testsubmodule.git
#(
#cd testsubmodule
#git status
#echo "hello" > hello
#git add hello
#git commit -m "adding hello"
#git push origin master
#)
#
#mkdir parent.git
#(
#cd parent.git
#git init
#echo "hello" > hello
#git add hello
#git commit -m "adding hello"
#git submodule add git@githost:/home/git/testsubmodule.git
#git commit -m "adding submodule"
#)
#
#rm /root/.ssh/config
#git clone --recursive parent.git testrepo
#ls -R testrepo


