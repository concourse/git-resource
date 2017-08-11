export TMPDIR=${TMPDIR:-/tmp}

# Configures ssh keys and config are placed in the default location under ~/.ssh
# rather than under /tmp. This makes writing the ssh cofig much easier.
configure_ssh() {
  rm -rf ~/.ssh
  mkdir -p ~/.ssh

  (jq -r '.source.private_key // empty' < $1) > ~/.ssh/id_rsa
  (jq -r '.source.ssh_config // empty' < $1) > ~/.ssh/config
  (jq -r '.source.known_hosts // empty' < $1) > ~/.ssh/known_hosts

  if [ -s ~/.ssh/id_rsa ]; then
    chmod 0600 ~/.ssh/id_rsa

    eval $(ssh-agent) >/dev/null 2>&1
    trap "kill $SSH_AGENT_PID" 0

    SSH_ASKPASS=$(dirname $0)/askpass.sh DISPLAY= ssh-add ~/.ssh/id_rsa >/dev/null
  fi
  
  if [ ! -s ~/.ssh/config ]; then
    cat > ~/.ssh/config <<EOF
StrictHostKeyChecking no
LogLevel quiet
EOF
  fi
}

configure_git_global() {
  local git_config_payload="$1"
  eval $(echo "$git_config_payload" | \
    jq -r ".[] | \"git config --global '\\(.name)' '\\(.value)'; \"")
}

configure_git_ssl_verification() {
  skip_ssl_verification=$(jq -r '.source.skip_ssl_verification // false' < $1)
  if [ "$skip_ssl_verification" = "true" ]; then
    export GIT_SSL_NO_VERIFY=true
  fi
}

add_git_metadata_basic() {
  local commit=$(git rev-parse HEAD | jq -R .)
  local author=$(git log -1 --format=format:%an | jq -s -R .)
  local author_date=$(git log -1 --format=format:%ai | jq -R .)

  jq ". + [
    {name: \"commit\", value: ${commit}},
    {name: \"author\", value: ${author}},
    {name: \"author_date\", value: ${author_date}, type: \"time\"}
  ]"
}

add_git_metadata_committer() {
  local author=$(git log -1 --format=format:%an | jq -s -R .)
  local author_date=$(git log -1 --format=format:%ai | jq -R .)
  local committer=$(git log -1 --format=format:%cn | jq -s -R .)
  local committer_date=$(git log -1 --format=format:%ci | jq -R .)

  if [ "$author" = "$committer" ] && [ "$author_date" = "$committer_date" ]; then
    jq ". + [
      {name: \"committer\", value: ${committer}},
      {name: \"committer_date\", value: ${committer_date}, type: \"time\"}
    ]"
  else
    cat
  fi
}

add_git_metadata_branch() {
  local branch=$(git show-ref --heads | \
    sed -n "s/^$(git rev-parse HEAD) refs\/heads\/\(.*\)/\1/p" |  \
    jq -R  ". | select(. != \"\")" | jq -r -s "map(.) | join (\",\")")

  if [ -n "${branch}" ]; then
    jq ". + [
      {name: \"branch\", value: \"${branch}\"}
    ]"
  else
    cat
  fi
}

add_git_metadata_tags() {
  local tags=$(git tag --points-at HEAD | \
    jq -R  ". | select(. != \"\")" | \
    jq -r -s "map(.) | join(\",\")")

  if [ -n "${tags}" ]; then
    jq ". + [
      {name: \"tags\", value: \"${tags}\"}
    ]"
  else
    cat
  fi
}

add_git_metadata_message() {
  local message=$(git log -1 --format=format:%B | jq -s -R .)

  jq ". + [
    {name: \"message\", value: ${message}, type: \"message\"}
  ]"
}

git_metadata() {
  jq -n "[]" | \
    add_git_metadata_basic | \
    add_git_metadata_committer | \
    add_git_metadata_branch | \
    add_git_metadata_tags | \
    add_git_metadata_message
}

configure_credentials() {
  local username=$(jq -r '.source.username // ""' < $1)
  local password=$(jq -r '.source.password // ""' < $1)

  rm -f $HOME/.netrc
  if [ "$username" != "" -a "$password" != "" ]; then
    echo "default login $username password $password" > $HOME/.netrc
  fi
}
