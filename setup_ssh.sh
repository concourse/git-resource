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
	chown $1 /home/$1/.ssh
	cat $2 > /home/$1/.ssh/authorized_keys
}

# make host keys for sshd
ssh-keygen -A
# set up authorized keys for each user to be under that users .ssh dir
perl -p -i -e 's|AuthorizedKeysFile.*|AuthorizedKeysFile %h/.ssh/authorized_keys|' /etc/ssh/sshd_config
/usr/sbin/sshd -E /var/log/sshd -o 'LogLevel VERBOSE'

mkdir -p /root/.ssh
cat << EOF > /root/.ssh/config
Host githost
  HostName 127.0.0.1
  ProxyCommand ssh proxy@127.0.0.1 -W 127.0.0.1:22
EOF

# set up root to know target host
ssh-keyscan 127.0.0.1 > /root/.ssh/known_hosts

# make root's key
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa

# make user accounts to ssh through
make_user proxy /root/.ssh/id_rsa.pub
make_user git /root/.ssh/id_rsa.pub

ssh git@githost 'echo $USER'
