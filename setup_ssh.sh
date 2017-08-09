#!/bin/bash

set -e

# $1 = username
# $2 = authorized key
make_user(){
	mkdir -p  home
	adduser -D -s /bin/bash $1
	# unlock the user account so that we can login as this user via ssh
	perl -p -i -e "s|($1.*?)\!(.*)|\1*\2|" /etc/shadow

	mkdir /home/$1/.ssh
	cat $2 > /home/$1/.ssh/authorized_keys
}

# make host keys for sshd
ssh-keygen -A
# set up authorized keys for each user to be under that users .ssh dir
perl -p -i -e 's|AuthorizedKeysFile.*|AuthorizedKeysFile %h/.ssh/authorized_keys|' /etc/ssh/sshd_config
/usr/sbin/sshd

# set up root to know this host
mkdir -p /root/.ssh
ssh-keyscan -t rsa 127.0.0.1 > /root/.ssh/known_hosts

for user in "${@}"; do
	ssh-keygen -t rsa -N "" -f "/root/.ssh/${user}"
	make_user "${user}" "/root/.ssh/${user}.pub"
	ssh  -i "/root/.ssh/${user}" "${user}@127.0.0.1" 'echo user $USER'
done
