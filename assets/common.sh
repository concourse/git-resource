# vim: set ft=sh

function load_pubkey() {
  private_key_path=$(mktemp /tmp/resource-in-private-key.XXXXX)

  (jq -r '.source.private_key // empty' < $1) > $private_key_path

  if [ -s $private_key_path ]; then
    chmod 0600 $private_key_path

    eval $(ssh-agent) >/dev/null 2>&1
    ssh-add $private_key_path >/dev/null 2>&1

    mkdir -p ~/.ssh
    echo 'StrictHostKeyChecking no' >> ~/.ssh/config
    echo 'LogLevel quiet' >> ~/.ssh/config
  fi
}
