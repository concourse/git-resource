#!/bin/sh

set -e

export TMPDIR_ROOT=$(mktemp -d /tmp/git-tests.XXXXXX)

$(dirname $0)/check.sh
$(dirname $0)/get.sh

echo -e '\e[32mall tests passed!\e[0m'

rm -rf $TMPDIR_ROOT
