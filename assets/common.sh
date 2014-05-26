# vim: set ft=sh

function load_pubkey() {
  private_key_path=$(mktemp /tmp/resource-in-private-key.XXXXX)

  (jq -r '.private_key // empty' < $1) > $private_key_path

  if [ -s $private_key_path ]; then
    chmod 0600 $private_key_path

    eval $(ssh-agent) 1>&2
    ssh-add $private_key_path 1>&2

    mkdir -p ~/.ssh
    echo 'StrictHostKeyChecking no' > ~/.ssh/config
  fi
}
