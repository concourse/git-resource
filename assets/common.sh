export TMPDIR=${TMPDIR:-/tmp}
export GIT_CRYPT_KEY_PATH=~/git-crypt.key

load_pubkey() {
  local private_key_path=$TMPDIR/git-resource-private-key
  local private_key_user=$(jq -r '.source.private_key_user // empty' <<< "$1")
  local forward_agent=$(jq -r '.source.forward_agent // false' <<< "$1")
  local passphrase="$(jq -r '.source.private_key_passphrase // empty' <<< "$1")"
  local uri=$(jq -r '.source.uri // ""' <<< "$1")

  (jq -r '.source.private_key // empty' <<< "$1") > $private_key_path

  if [ -s $private_key_path ]; then
    chmod 0600 $private_key_path

    # create or re-initialize ssh-agent
    init_ssh_agent

    SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=$(dirname $0)/askpass.sh GIT_SSH_PRIVATE_KEY_PASS="$passphrase" DISPLAY= ssh-add $private_key_path > /dev/null

    mkdir -p ~/.ssh
    cat > ~/.ssh/config <<EOF
StrictHostKeyChecking no
LogLevel quiet
EOF

    # Handle ssh:// URLs with custom ports
    if [[ "$uri" =~ ^ssh://([^@]+@)?([^:/]+):([0-9]+) ]]; then
      local ssh_host="${BASH_REMATCH[2]}"
      local ssh_port="${BASH_REMATCH[3]}"

      cat >> ~/.ssh/config <<EOF

Host $ssh_host
  Port $ssh_port
EOF
    fi

    if [ ! -z "$private_key_user" ]; then
      cat >> ~/.ssh/config <<EOF
User $private_key_user
EOF
    fi

    if [ "$forward_agent" = "true" ]; then
      cat >> ~/.ssh/config <<EOF
ForwardAgent yes
EOF
    fi

    chmod 0600 ~/.ssh/config
  fi
}

init_ssh_agent() {

  # validate if ssh-agent exist
  set +e
  ssh-add -l &> /dev/null
  exit_code=$?
  set -e

  if [[ ${exit_code} -eq 2 ]]; then
    # ssh-agent does not exist, create ssh-agent
    eval $(ssh-agent) > /dev/null 2>&1
    trap "kill $SSH_AGENT_PID" EXIT
  else
    # ssh-agent exist, remove all identities
    ssh-add -D &> /dev/null
  fi

}

configure_https_tunnel() {
  tunnel=$(jq -r '.source.https_tunnel // empty' <<< "$1")

  if [ ! -z "$tunnel" ]; then
    host=$(echo "$tunnel" | jq -r '.proxy_host // empty')
    port=$(echo "$tunnel" | jq -r '.proxy_port // empty')
    user=$(echo "$tunnel" | jq -r '.proxy_user // empty')
    password=$(echo "$tunnel" | jq -r '.proxy_password // empty')

    pass_file=""
    if [ ! -z "$user" ]; then
      cat > ~/.ssh/tunnel_config <<EOF
proxy_user = $user
proxy_passwd = $password
EOF
      chmod 0600 ~/.ssh/tunnel_config
      pass_file="-F ~/.ssh/tunnel_config"
    fi

    if [[ ! -z $host && ! -z $port ]]; then
      echo "ProxyCommand /usr/bin/proxytunnel $pass_file -p $host:$port -d %h:%p" >> ~/.ssh/config
    fi
  fi
}

configure_git_global() {
  git config --global gc.autoDetach false
  local git_config_payload="$1"
  eval $(echo "$git_config_payload" | \
    jq -r ".[] | \"git config --global '\\(.name)' '\\(.value)'; \"")
}

configure_git_local() {
  local git_config_payload="$1"
  if [ -n "$git_config_payload" ] && [ "$git_config_payload" != "[]" ]; then
    echo "$git_config_payload" | jq -r '.[] | [.name, .value] | @tsv' | \
      while IFS=$'\t' read -r name value; do
        git config "$name" "$value"
      done
  fi
}

configure_git_ssl_verification() {
  skip_ssl_verification=$(jq -r '.source.skip_ssl_verification // false' <<< "$1")
  if [ "$skip_ssl_verification" = "true" ]; then
    export GIT_SSL_NO_VERIFY=true
  fi
}

add_git_metadata_basic() {
  local commit=$(git rev-parse HEAD)
  local author=$(git log -1 --format=format:%an)
  local author_date=$(git log -1 --format=format:%ai)

  jq --arg commit "$commit" \
     --arg author "$author" \
     --arg author_date "$author_date" \
  '. + [
    {name: "commit", value: $commit},
    {name: "author", value: $author},
    {name: "author_date", value: $author_date, type: "time"}
  ]'
}

add_git_metadata_committer() {
  local author=$(git log -1 --format=format:%an)
  local author_date=$(git log -1 --format=format:%ai)
  local committer=$(git log -1 --format=format:%cn)
  local committer_date=$(git log -1 --format=format:%ci)

  if [ "$author" = "$committer" ] && [ "$author_date" = "$committer_date" ]; then
    jq --arg committer "$committer" --arg committer_date "$committer_date" '. + [
      {name: "committer", value: $committer},
      {name: "committer_date", value: $committer_date, type: "time"}
    ]'
  else
    cat
  fi
}

add_git_metadata_branch() {
  local branch=$(git show-ref --heads | \
    sed -n "s/^$(git rev-parse HEAD) refs\/heads\/\(.*\)/\1/p" |  \
    jq -R  ". | select(. != \"\")" | jq -r -s "map(.) | join (\",\")")

  if [ -n "${branch}" ]; then
    jq --arg branch "$branch" '. + [
      {name: "branch", value: $branch}
    ]'
  else
    cat
  fi
}

add_git_metadata_tags() {
  local tags=$(git tag --points-at HEAD | \
    jq -R  ". | select(. != \"\")" | \
    jq -r -s "map(.) | join(\",\")")

  if [ -n "${tags}" ]; then
    jq --arg tags "$tags" '. + [
      {name: "tags", value: $tags}
    ]'
  else
    cat
  fi
}

add_git_metadata_tag() {
  local tag=$(git tag --points-at HEAD)

  if [ -n "${tag}" ]; then
    jq --arg tag "$tag" '. + [
      {name: "tag", value: $tag}
    ]'
  else
    cat
  fi
}

add_git_metadata_message() {
  local message=$(git log -1 --format=format:%B | head -c 10240)

  jq --arg message "$message" '. + [
    {name: "message", value: $message, type: "message"}
  ]'
}

add_git_metadata_url() {
  local commit=$(git rev-parse HEAD)
  local origin=$(git remote get-url --all origin) 2> /dev/null

  # This is not exhaustive for remote URL formats, but does cover the
  # most common hosting scenarios for where a commit URL exists
  if [[ ! $origin =~ ^(https?://|ssh://git@|git@)([^/]+)/(.*)$ ]]; then
    jq ". + []"
  else
    local host=${BASH_REMATCH[2]}
    local repo_path=${BASH_REMATCH[3]%.git}

    # Remap scp-style names so that "github.com:concourse" + "git-resource"
    # becomes "github.com" + "concourse/git-resource"
    if [[ ${BASH_REMATCH[1]} == "git@" && $host == *:* ]]; then
      repo_path="${host#*:}/${repo_path}"
      host=${host%%:*}
    fi

    local url=""
    case $host in
      *github* | *gogs* )
        url="https://${host}/${repo_path}/commit/${commit}" ;;
      *gitlab*  )
        url="https://${host}/${repo_path}/-/commit/${commit}" ;;
      *bitbucket* )
        url="https://${host}/${repo_path}/commits/${commit}";;
    esac

    if [ -n "$url" ]; then
      jq --arg url "$url" '. + [
        {name: "url", value: $url}
      ]'
    else
      jq ". + []"
    fi
  fi
}

git_metadata() {
  jq -n "[]" | \
    add_git_metadata_basic | \
    add_git_metadata_committer | \
    add_git_metadata_branch | \
    add_git_metadata_tags | \
    add_git_metadata_message | \
    add_git_metadata_url
}

git_tag_metadata() {
  jq -n "[]" | \
    add_git_metadata_basic | \
    add_git_metadata_committer | \
    add_git_metadata_tag | \
    add_git_metadata_message | \
    add_git_metadata_url
}

configure_submodule_credentials() {
  local username
  local password
  if [[ "$(jq -r '.source.submodule_credentials // ""' <<< "$1")" == "" ]]; then
    return
  fi

  for k in $(jq -r '.source.submodule_credentials | keys | .[]' <<< "$1"); do
    host=$(jq -r --argjson k "$k" '.source.submodule_credentials[$k].host // ""' <<< "$1")
    username=$(jq -r --argjson k "$k" '.source.submodule_credentials[$k].username // ""' <<< "$1")
    password=$(jq -r --argjson k "$k" '.source.submodule_credentials[$k].password // ""' <<< "$1")
    if [ "$username" != "" -a "$password" != "" -a "$host" != "" ]; then
      echo "machine $host login $username password $password" >> "${HOME}/.netrc"
    fi
  done
}

configure_credentials() {
  local username=$(jq -r '.source.username // ""' <<< "$1")
  local password=$(jq -r '.source.password // ""' <<< "$1")

  rm -f $HOME/.netrc
  configure_submodule_credentials "$1"

  if [ "$username" != "" -a "$password" != "" ]; then
    local credential_hosts=$(jq -r '(.source.credential_hosts // []) | if type == "array" then .[] else . end' <<< "$1")
    if [ "$credential_hosts" != "" ]; then
      for host in $credential_hosts; do
        echo "machine $host login $username password $password" >> "${HOME}/.netrc"
      done
    else
      echo "default login $username password $password" >> "${HOME}/.netrc"
    fi
  fi
}

load_git_crypt_key() {
  local git_crypt_tmp_key_path=$TMPDIR/git-resource-git-crypt-key

  (jq -r '.source.git_crypt_key // empty' <<< "$1") > $git_crypt_tmp_key_path

  if [ -s $git_crypt_tmp_key_path ]; then
      cat $git_crypt_tmp_key_path | tr ' ' '\n' | base64 -d > $GIT_CRYPT_KEY_PATH
  fi
}

create_github_app_jwt() {
  # reference: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app
  local client_id=$1
  local pem=$2
  local iat=$3
  local exp=$4

  b64enc() { base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

  local header_json='{"typ":"JWT","alg":"RS256"}'

  local header=$(echo -n "${header_json}" | b64enc)

  local payload_json="{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${client_id}\"}"

  local payload=$(echo -n "${payload_json}" | b64enc)

  local header_payload="${header}.${payload}"
  local signature
  signature=$(set -o pipefail; openssl dgst -sha256 -sign <(echo -n "${pem}") \
      <(echo -n "${header_payload}") | b64enc) || {
    echo "error: openssl signing failed" >&2
    return 1
  }

  echo "${header_payload}.${signature}"
}

get_github_app_install_id() {
  # references:
  # https://docs.github.com/en/rest/apps/apps?apiVersion=2026-03-10#get-an-organization-installation-for-the-authenticated-app
  # https://docs.github.com/en/rest/apps/apps?apiVersion=2026-03-10#get-a-repository-installation-for-the-authenticated-app
  # https://docs.github.com/en/rest/apps/apps?apiVersion=2026-03-10#get-a-user-installation-for-the-authenticated-app
  local base_api_url=$1
  local jwt=$2
  local org=$3
  local user=$4
  local repo=$5
  local install_url=""

  if [ -n "$user" ] && [ -z "$repo" ]; then
    install_url="${base_api_url}/users/${user}/installation"
  elif [ -n "$org" ]; then
    install_url="${base_api_url}/orgs/${org}/installation"
  elif [ -n "$user" ] && [ -n "$repo" ]; then
    install_url="${base_api_url}/repos/${user}/${repo}/installation"
  else
    # this should be guarded by the calling function
    return 1
  fi

  local install_id_resp=$(curl --max-time 30 --retry 3 -s -X GET -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2026-03-10" -H "Authorization: Bearer ${jwt}" "$install_url")
  local install_id=$(jq -r '.id // empty' <<< "$install_id_resp")

  if [ -z "$install_id" ]; then
    echo "error: $install_id_resp" >&2
    return 1
  fi

  echo $install_id
}

get_github_app_access_token() {
  # reference: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app?apiVersion=2026-03-10&versionId=free-pro-team%40latest&category=apps&subcategory=oauth-applications&productId=apps&restPage=creating-github-apps%2Cauthenticating-with-a-github-app%2Cgenerating-a-user-access-token-for-a-github-app
  local base_api_url=$1
  local jwt=$2
  local install_id=$3

  local access_token_resp=$(curl --max-time 30 --retry 3 -s -X POST -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2026-03-10" -H "Authorization: Bearer ${jwt}" "${base_api_url}/app/installations/${install_id}/access_tokens")
  local access_token=$(jq -r '.token // empty' <<< "$access_token_resp")

  if [ -z "$access_token" ]; then
      echo "error: $access_token_resp" >&2
    return 1
  fi

  echo "$access_token"
}

setup_github_app_credentials() {
  local uri=$(jq -r '.source.uri // empty' <<< "$1")
  local app_id=$(jq -r '.source.github_app_id // empty' <<< "$1")
  local private_key=$(jq -r '.source.github_app_private_key // empty' <<< "$1")
  local org=$(jq -r '.source.github_app_org // empty' <<< "$1")
  local user=$(jq -r '.source.github_app_user // empty' <<< "$1")
  local repo=$(jq -r '.source.github_app_repo // empty' <<< "$1")

  if [[ ! ( -n "${uri}" && -n "${app_id}" && -n "${private_key}" && ( -n "${org}" || -n "${user}" )) ]]; then
    return
  fi

  if [[ ! $uri =~ ^(https://)([^/]+)/.*$ ]]; then
    echo "github app authentication needs an https:// source.uri"
    return 1
  fi

  local host=${BASH_REMATCH[2]}
  local base_api_url="https://api.${host}"

  local now=$(date +%s)
  local iat=$((${now} - 60))  # Issues 60 seconds in the past
  local exp=$((${now} + 600)) # Expires 10 minutes in the future

  local jwt
  jwt=$(create_github_app_jwt "$app_id" "$private_key" "$iat" "$exp")
  if [[ -z "$jwt" ]]; then
    echo "failed to create github app jwt"
    return 1
  fi

  local install_id
  install_id=$(get_github_app_install_id "$base_api_url" "$jwt" "$org" "$user" "$repo")
  if [[ -z "$install_id" ]]; then
    echo "failed to get github app installation id"
    return 1
  fi

  local access_token
  access_token=$(get_github_app_access_token "$base_api_url" "$jwt" "$install_id")
  if [[ -z "$access_token" ]]; then
    echo "failed to get github app access token"
    return 1
  fi

  git config --global "credential.https://${host}.helper" "!f() { echo \"username=x-access-token\"; echo \"password=${access_token}\"; }; f"
}
