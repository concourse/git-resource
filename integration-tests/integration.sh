#!/bin/bash

set -e

basedir="$(dirname "$0")"
. "$basedir/../test/helpers.sh"
. "$basedir/helpers.sh"

it_can_check_through_a_tunnel() {
  output=$(check_uri_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination "$@" 2>&1)
  echo "$output"

  ( echo "$output" | grep 'Via localhost:3128 ->' >/dev/null 2>&1 )
  rc=$?

  test "$rc" -eq "0"
}

it_can_check_with_empty_tunnel_information() {
  output=$(check_uri_with_private_key_and_incomplete_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination "$@" 2>&1)
  echo "$output"

  set +e
  ( echo "$output" | grep 'Via localhost:3128 ->' >/dev/null 2>&1 )
  rc=$?
  set -e
  
  test "$rc" -ne "0"
}

it_can_get_through_a_tunnel() {
  get_uri_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination "$@"
}

it_can_put_through_a_tunnel() {
  get_uri_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination "$@"

  pushd $TMPDIR
    git clone destination staging
    date >> staging/test-file

    pushd staging
      git add .
      git commit -m "Integration Test $(date)"
    popd
  popd

  put_uri_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination $TMPDIR/staging "$@"
}

it_can_check_through_a_tunnel_with_auth() {
  it_can_check_through_a_tunnel "$basedir/tunnel/auth"
}

it_can_get_through_a_tunnel_with_auth() {
  it_can_get_through_a_tunnel "$basedir/tunnel/auth"
}

it_can_put_through_a_tunnel_with_auth() {
  it_can_put_through_a_tunnel "$basedir/tunnel/auth"
}

it_cant_check_through_a_tunnel_without_auth() {
  set +e
  test_auth_failure "$(check_uri_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination "$@" 2>&1)"
}

it_cant_get_through_a_tunnel_without_auth() {
  set +e
  test_auth_failure "$(get_uri_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination "$@" 2>&1)"
}

it_cant_put_through_a_tunnel_without_auth() {
  get_uri_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination "$basedir/tunnel/auth"
  pushd $TMPDIR
    git clone destination staging
    date >> staging/test-file

    pushd staging
      git add .
      git commit -m "Integration Test $(date)"
    popd
  popd

  set +e
  test_auth_failure "$(put_uri_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" $TMPDIR/destination $TMPDIR/staging "$@" 2>&1)"
}

init_integration_tests $basedir
run it_can_check_with_empty_tunnel_information
run_with_unauthenticated_proxy "$basedir" it_can_check_through_a_tunnel
run_with_unauthenticated_proxy "$basedir" it_can_get_through_a_tunnel
run_with_unauthenticated_proxy "$basedir" it_can_put_through_a_tunnel
run_with_unauthenticated_proxy "$basedir" it_can_check_through_a_tunnel_with_auth
run_with_unauthenticated_proxy "$basedir" it_can_get_through_a_tunnel_with_auth
run_with_unauthenticated_proxy "$basedir" it_can_put_through_a_tunnel_with_auth

run_with_authenticated_proxy "$basedir" it_can_check_through_a_tunnel_with_auth
run_with_authenticated_proxy "$basedir" it_can_get_through_a_tunnel_with_auth
run_with_authenticated_proxy "$basedir" it_can_put_through_a_tunnel_with_auth
run_with_authenticated_proxy "$basedir" it_cant_check_through_a_tunnel_without_auth
run_with_authenticated_proxy "$basedir" it_cant_get_through_a_tunnel_without_auth
run_with_authenticated_proxy "$basedir" it_cant_put_through_a_tunnel_without_auth
