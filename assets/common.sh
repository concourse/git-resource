export TMPDIR=${TMPDIR:-/tmp}

load_pubkey() {
  local private_key_path=$TMPDIR/git-resource-private-key

  (jq -r '.source.private_key // empty' < $1) > $private_key_path

  if [ -s $private_key_path ]; then
    chmod 0600 $private_key_path

    eval $(ssh-agent) >/dev/null 2>&1
    trap "kill $SSH_AGENT_PID" 0

    SSH_ASKPASS=/opt/resource/askpass.sh DISPLAY= ssh-add $private_key_path >/dev/null

    mkdir -p ~/.ssh
    cat > ~/.ssh/config <<EOF
StrictHostKeyChecking no
LogLevel quiet
EOF
    chmod 0600 ~/.ssh/config
  fi
}

configure_git_ssl_verification() {
  skip_ssl_verification=$(jq -r '.source.skip_ssl_verification // false' < $1)
  if [ "$skip_ssl_verification" = "true" ]; then
    export GIT_SSL_NO_VERIFY=true
  fi
}

git_metadata() {
  local commit=$(git rev-parse HEAD | jq -R .)
  local author=$(git log -1 --format=format:%an | jq -s -R .)
  local author_date=$(git log -1 --format=format:%ai | jq -R .)
  local committer=$(git log -1 --format=format:%cn | jq -s -R .)
  local committer_date=$(git log -1 --format=format:%ci | jq -R .)
  local message=$(git log -1 --format=format:%B | jq -s -R .)

  if [ "$author" = "$committer" ] && [ "$author_date" = "$committer_date" ]; then
    jq -n "[
      {name: \"commit\", value: ${commit}},
      {name: \"author\", value: ${author}},
      {name: \"author_date\", value: ${author_date}, type: \"time\"},
      {name: \"message\", value: ${message}, type: \"message\"}
    ]"
  else
    jq -n "[
      {name: \"commit\", value: ${commit}},
      {name: \"author\", value: ${author}},
      {name: \"author_date\", value: ${author_date}, type: \"time\"},
      {name: \"committer\", value: ${committer}},
      {name: \"committer_date\", value: ${committer_date}, type: \"time\"},
      {name: \"message\", value: ${message}, type: \"message\"}
    ]"
  fi
}

turn_off_git_lfs() {
  git lfs uninstall
}
