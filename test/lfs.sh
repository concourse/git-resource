set -e

source $(dirname $0)/helpers.sh

# TODO:  This should move to an identical repo under concourse's control.
lfsrepo="https://github.com/vectorstorm/lfstest"

# These tests work by cloning the $lfsrepo specified above.  The repo contains
# just a file "test", which is served via LFS.  If we get the LFS file, the
# file will contain only the string "SUCCESS".  If we do NOT get the LFS file,
# then the file will contain an LFS pointer to the file.  These tests verify
# that we DO and DON'T fetch the LFS file as expected, based upon the presenece
# of the git_disable_lfs parameter.

it_can_clone_with_lfs() {
	cd $(mktemp -d $TMPDIR/repo.XXXXXX)
	local dest=$TMPDIR/destination

	get_uri $lfsrepo $dest

	test -e "$dest/test"
	test "$(cat $dest/test)" = "SUCCESS"
}

it_can_clone_with_lfs_disabled() {
	cd $(mktemp -d $TMPDIR/repo.XXXXXX)
	local dest=$TMPDIR/destination

	get_uri_disable_lfs $lfsrepo $dest

	test -e "$dest/test"
	test "$(cat $dest/test)" != "SUCCESS"
}

run it_can_clone_with_lfs
run it_can_clone_with_lfs_disabled

