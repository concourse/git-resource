function load_pubkey() {
  private_key_path=$(mktemp /tmp/resource-in-private-key.XXXXX)

  (jq -r '.source.private_key // .params.private_key // empty' < $1) > $private_key_path

  if [ -s $private_key_path ]; then
    chmod 0600 $private_key_path

    eval $(ssh-agent) >/dev/null 2>&1
    ssh-add $private_key_path >/dev/null 2>&1

    mkdir -p ~/.ssh
    echo 'StrictHostKeyChecking no' >> ~/.ssh/config
    echo 'LogLevel quiet' >> ~/.ssh/config
  fi
}

function git_metadata() {
  jq -n "[
    {name: \"commit\", value: $(git rev-parse HEAD | jq -R .)},
    {name: \"author\", value: $(git log -1 --format=format:%an | jq -s -R .)},
    {name: \"author_date\", value: $(git log -1 --format=format:%ai | jq -R .)},
    {name: \"committer\", value: $(git log -1 --format=format:%cn | jq -s -R .)},
    {name: \"committer_date\", value: $(git log -1 --format=format:%ci | jq -R .)},
    {name: \"message\", value: $(git log -1 --format=format:%B | jq -s -R .)}
  ]"
}
