# Git Resource

Tracks the commits in a [git](http://git-scm.com/) repository.

## Source Configuration

* `uri`: *Required.* The location of the repository.

* `branch`: *Required.* The branch to track. If not specified, the
repository's default branch is assumed.


## Behavior

### `check`: Check for new commits.

The repository is cloned (or pulled if already present), and any commits
made after the given version are returned. If no version is given, the ref
for `HEAD` is returned.


### `in`: Clone the repository, at the given ref.

Clones the repository to the destination, and locks it down to a given ref.
Returns the resulting ref as the version.

Submodules are initialized and updated recursively.


#### Parameters

* `fetch`: *Optional.* Additional branches to fetch so that they're
available to the build.


### `out`: Push to a repository.

Push a repository to the source's URI and branch. All tags are also pushed
to the source.

#### Parameters

* `repository`: *Required.* The path of the repository to push to the source.

* `rebase`: *Optional.* If pushing fails with non-fast-forward, continuously
attempt rebasing and pushing.
