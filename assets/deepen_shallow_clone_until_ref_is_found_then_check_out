#!/bin/bash
# vim: set ft=sh

set -e

readonly max_depth=128

declare depth="$1"
readonly ref="$2"
readonly tagflag="$3"

# A shallow clone may not contain the Git commit $ref:
# 1. The depth of the shallow clone is measured backwards from the latest
#    commit on the given head (master or branch), and in the meantime there may
#    have been more than $depth commits pushed on top of our $ref.
# 2. If there's a path filter (`paths`/`ignore_paths`), then there may be more
#    than $depth such commits pushed to the head (master or branch) on top of
#    $ref that are not affecting the filtered paths.
#
# In either case we try to deepen the shallow clone until we find $ref, reach
# the max depth of the repo, or give up after a given depth and resort to deep
# clone.

git_dir="$(git rev-parse --git-dir)"
readonly git_dir

while ! git checkout -q "$ref" &>/dev/null; do
  # once the depth of a shallow clone reaches the max depth of the origin
  # repo, Git silenty turns it into a deep clone
  if [ ! -e "$git_dir"/shallow ]; then
    echo "Reached max depth of the origin repo while deepening the shallow clone, it's a deep clone now"
    break
  fi

  echo "Could not find ref ${ref} in a shallow clone of depth ${depth}"

  (( depth *= 2 ))

  if [ "$depth" -gt "$max_depth" ]; then
    echo "Reached depth threshold ${max_depth}, falling back to deep clone..."
    git fetch --unshallow origin $tagflag

    break
  fi

  echo "Deepening the shallow clone to depth ${depth}..."
  git fetch --depth "$depth" origin $tagflag
done

git checkout -q "$ref"
