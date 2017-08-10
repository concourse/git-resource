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
Host testy
  HostName 127.0.0.1
  ProxyCommand ssh proxy@127.0.0.1 -W 127.0.0.1:22
EOF

# set up root to know this host
ssh-keyscan 127.0.0.1 > /root/.ssh/known_hosts
#ssh-keyscan -t rsa testy > /root/.ssh/known_hosts

# make root's key
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa

make_user proxy /root/.ssh/id_rsa.pub
su proxy -c 'ssh-keygen -t rsa -N "" -f /home/proxy/.ssh/id_rsa'
su proxy -c 'ssh-keyscan 127.0.0.1 > /home/proxy/.ssh/known_hosts'

make_user git /root/.ssh/id_rsa.pub

  #ProxyCommand ssh proxy@127.0.0.1
  #ProxyCommand ssh proxy@127.0.0.1 ssh git@127.0.0.1

ssh git@testy 'echo $USER'
cat /root/.ssh/known_hosts
