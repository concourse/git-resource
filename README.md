# Git Resource

Tracks the commits in a [git](http://git-scm.com/) repository.

## Source Configuration

* `uri`: *Required.* The location of the repository.

* `branch`: The branch to track. This is *optional* if the resource is
   only used in `get` steps; however, it is *required* when used in a `put` step. If unset for `get`, the repository's default branch is used; usually `master` but [could be different](https://help.github.com/articles/setting-the-default-branch/).

* `private_key`: *Optional.* Private key to use when pulling/pushing.
    Example:

    ```yaml
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAtCS10/f7W7lkQaSgD/mVeaSOvSF9ql4hf/zfMwfVGgHWjj+W
      <Lots more text>
      DWiJL+OFeg9kawcUL6hQ8JeXPhlImG6RTUffma9+iGQyyBMCGd1l
      -----END RSA PRIVATE KEY-----
    ```

* `private_key_user`: *Optional.* Enables setting User in the ssh config.

* `private_key_passphrase`: *Optional.* To unlock `private_key` if it is protected by a passphrase.

* `forward_agent`: *Optional* Enables ForwardAgent SSH option when set to true. Useful when using proxy/jump hosts. Defaults to false.

* `username`: *Optional.* Username for HTTP(S) auth when pulling/pushing.
  This is needed when only HTTP/HTTPS protocol for git is available (which does not support private key auth)
  and auth is required.

* `password`: *Optional.* Password for HTTP(S) auth when pulling/pushing.

* `paths`: *Optional.* If specified (as a list of glob patterns), only changes
  to the specified files will yield new versions from `check`.

* `ignore_paths`: *Optional.* The inverse of `paths`; changes to the specified
  files are ignored.

  Note that if you want to push commits that change these files via a `put`,
  the commit will still be "detected", as [`check` and `put` both introduce
  versions](https://github.com/concourse/concourse/issues/534).
  To avoid this you should define a second resource that you use for commits
  that change files that you don't want to feed back into your pipeline - think
  of one as read-only (with `ignore_paths`) and one as write-only (which
  shouldn't need it).

* `skip_ssl_verification`: *Optional.* Skips git ssl verification by exporting
  `GIT_SSL_NO_VERIFY=true`.

* `tag_filter`: *Optional.* If specified, the resource will only detect commits
  that have a tag matching the expression that have been made against
  the `branch`. Patterns are [glob(7)](http://man7.org/linux/man-pages/man7/glob.7.html)
  compatible (as in, bash compatible).

* `tag_regex`: *Optional.* If specified, the resource will only detect commits
  that have a tag matching the expression that have been made against
  the `branch`. Patterns are [grep](https://www.gnu.org/software/grep/manual/grep.html)
  compatible (extended matching enabled, matches entire lines only). Ignored if
  `tag_filter` is also specified.

* `fetch_tags`: *Optional.* If `true` the flag `--tags` will be used to fetch
  all tags in the repository. If `false` no tags will be fetched.

* `submodule_credentials`: *Optional.* List of credentials for HTTP(s) auth when pulling/pushing private git submodules which are not stored in the same git server as the container repository.
    Example:

    ```
    submodule_credentials:
    - host: github.com
      username: git-user
      password: git-password
    - <another-configuration>
    ```

    Note that `host` is specified with no protocol extensions.

* `git_config`: *Optional.* If specified as (list of pairs `name` and `value`)
  it will configure git global options, setting each name with each value.

  This can be useful to set options like `credential.helper` or similar.

  See the [`git-config(1)` manual page](https://www.kernel.org/pub/software/scm/git/docs/git-config.html)
  for more information and documentation of existing git options.

* `disable_ci_skip`: *Optional.* Allows for commits that have been labeled with `[ci skip]` or `[skip ci]`
   previously to be discovered by the resource.

* `commit_verification_keys`: *Optional.* Array of GPG public keys that the
  resource will check against to verify the commit (details below).

* `commit_verification_key_ids`: *Optional.* Array of GPG public key ids that
  the resource will check against to verify the commit (details below). The
  corresponding keys will be fetched from the key server specified in
  `gpg_keyserver`. The ids can be short id, long id or fingerprint.

* `gpg_keyserver`: *Optional.* GPG keyserver to download the public keys from.
  Defaults to `hkp://keyserver.ubuntu.com/`.

* `git_crypt_key`: *Optional.* Base64 encoded
  [git-crypt](https://github.com/AGWA/git-crypt) key. Setting this will
  unlock / decrypt the repository with `git-crypt`. To get the key simply
  execute `git-crypt export-key -- - | base64` in an encrypted repository.

* `https_tunnel`: *Optional.* Information about an HTTPS proxy that will be used to tunnel SSH-based git commands over.
  Has the following sub-properties:
  * `proxy_host`: *Required.* The host name or IP of the proxy server
  * `proxy_port`: *Required.* The proxy server's listening port
  * `proxy_user`: *Optional.* If the proxy requires authentication, use this username
  * `proxy_password`: *Optional.* If the proxy requires authenticate,
      use this password

* `commit_filter`: *Optional.* Object containing commit message filters
  * `commit_filter.exclude`: *Optional.* Array containing strings that should
    cause a commit to be skipped
  * `commit_filter.include`: *Optional.* Array continuing strings that
    *MUST* be included in commit messages for the commit to not be
    skipped

* `version_depth`: *Optional.* The number of versions to return when performing a check

* `search_remote_refs`: *Optional.* True to search remote refs for the input version when checking out during the get step.
    This can be useful during the `get` step after a `put` step for unconventional workflows. One example workflow is the
    `refs/for/<branch>` workflow used by gerrit which 'magically' creates a `refs/changes/nnn` reference instead
    of the straight forward `refs/for/<branch>` reference that a git remote would usually create.
    See also `out params.refs_prefix`.

### Example

Resource configuration for a private repo with an HTTPS proxy:

``` yaml
resources:
- name: source-code
  type: git
  source:
    uri: git@github.com:concourse/git-resource.git
    branch: master
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAtCS10/f7W7lkQaSgD/mVeaSOvSF9ql4hf/zfMwfVGgHWjj+W
      <Lots more text>
      DWiJL+OFeg9kawcUL6hQ8JeXPhlImG6RTUffma9+iGQyyBMCGd1l
      -----END RSA PRIVATE KEY-----
    git_config:
    - name: core.bigFileThreshold
      value: 10m
    disable_ci_skip: true
    git_crypt_key: AEdJVEN...snip...AAA==
    https_tunnel:
      proxy_host: proxy-server.mycorp.com
      proxy_port: 3128
      proxy_user: myuser
      proxy_password: myverysecurepassword
```

Resource configuration for a private repo with a private submodule from different git server:

``` yaml
resources:
- name: source-code
  type: git
  source:
    uri: git@github.com:concourse/git-resource.git
    branch: master
    submodule_credentials:
    - host: some.other.git.server
      username: user
      password: verysecurepassword
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAtCS10/f7W7lkQaSgD/mVeaSOvSF9ql4hf/zfMwfVGgHWjj+W
      <Lots more text>
      DWiJL+OFeg9kawcUL6hQ8JeXPhlImG6RTUffma9+iGQyyBMCGd1l
      -----END RSA PRIVATE KEY-----
```

Fetching a repo with only 100 commits of history:

``` yaml
- get: source-code
  params: {depth: 100}
```

Pushing local commits to the repo:

``` yaml
- get: some-other-repo
- put: source-code
  params: {repository: some-other-repo}
```

Fetching a repo pinned to a specific commit:

``` yaml
resources:
- name: source-code
  type: git
  source:
    uri: git@github.com:concourse/git-resource.git
    branch: master
  version:
    ref: commit-sha
```

## Behavior

### `check`: Check for new commits

The repository is cloned (or pulled if already present), and any commits
from the given version on are returned. If no version is given, the ref
for `HEAD` is returned.

Any commits that contain the string `[ci skip]` will be ignored. This
allows you to commit to your repository without triggering a new version.

### `in`: Clone the repository, at the given ref

Clones the repository to the destination, and locks it down to a given ref.
It will return the same given ref as version.

`git-crypt` encrypted repositories will automatically be decrypted, when the
correct key is provided set in `git_crypt_key`.

#### Parameters

* `depth`: *Optional.* If a positive integer is given, *shallow* clone the
  repository using the `--depth` option. To prevent newer commits that do
  not pass a `paths` filter test from skewing the cloned history away from
  `version.ref`, this resource will automatically deepen the clone until
  `version.ref` is found again. It will deepen with exponentially increasing steps
  until a maximum of 127 + `depth` commits or else resort to unshallow the repository.

* `fetch_tags`: *Optional.* If `true` the flag `--tags` will be used to fetch
  all tags in the repository. If `false` no tags will be fetched.

  Will override `fetch_tags` source configuration if defined.

* `submodules`: *Optional.* If `none`, submodules will not be
  fetched. If specified as a list of paths, only the given paths will be
  fetched. If not specified, or if `all` is explicitly specified, all
  submodules are fetched.

* `submodule_recursive`: *Optional.* If `false`, a flat submodules checkout is performed. If not specified, or if `true` is explicitly specified, a recursive checkout is performed.

* `submodule_remote`: *Optional.* If `true`, the submodules are checked out for the specified remote branch specified in the `.gitmodules` file of the repository. If not specified, or if `false` is explicitly specified, the tracked sub-module revision of the repository is used to check out the submodules.

* `disable_git_lfs`: *Optional.* If `true`, will not fetch Git LFS files.

* `clean_tags`: *Optional.* If `true` all incoming tags will be deleted. This
  is useful if you want to push tags, but have reasonable doubts that the tags
  cached with the resource are outdated. The default value is `false`.

* `short_ref_format`: *Optional.* When populating `.git/short_ref` use this `printf` format. Defaults to `%s`.

* `timestamp_format`: *Optional.* When populating `.git/commit_timestamp` use this options to pass to [`git log --date`](https://git-scm.com/docs/git-log#Documentation/git-log.txt---dateltformatgt). Defaults to `iso8601`.

* `describe_ref_options`: *Optional.* When populating `.git/describe_ref` use this options to call [`git describe`](https://git-scm.com/docs/git-describe). Defaults to `--always --dirty --broken`.

#### GPG signature verification

If `commit_verification_keys` or `commit_verification_key_ids` is specified in
the source configuration, it will additionally verify that the resulting commit
has been GPG signed by one of the specified keys. It will error if this is not
the case.

#### Additional files populated

* `.git/committer`: For committer notification on failed builds.
 This special file `.git/committer` which is populated with the email address
 of the author of the last commit. This can be used together with  an email
 resource like [mdomke/concourse-email-resource](https://github.com/mdomke/concourse-email-resource)
 to notify the committer in an on_failure step.

* `.git/ref`: Version reference detected and checked out. It will usually contain
 the commit SHA-1 ref, but also the detected tag name when using `tag_filter` or
 `tag_regex`.

* `.git/short_ref`: Short (first seven characters) of the `.git/ref`. Can be templated with `short_ref_format` parameter.

* `.git/commit_message`: For publishing the Git commit message on successful builds.

 * `.git/commit_timestamp`: For tagging builds with a timestamp.

* `.git/describe_ref`: Version reference detected and checked out. Can be templated with `describe_ref_options` parameter.
 By default, it will contain the `<latest annoted git tag>-<the number of commit since the tag>-g<short_ref>` (eg. `v1.6.2-1-g13dfd7b`).
 If the repo was never tagged before, this falls back to a short commit SHA-1 ref.

### `out`: Push to a repository

Push the checked-out reference to the source's URI and branch. All tags are
also pushed to the source. If a fast-forward for the branch is not possible
and the `rebase` parameter is not provided, the push will fail.

#### Parameters

* `repository`: *Required.* The path of the repository to push to the source.

* `rebase`: *Optional.* If pushing fails with non-fast-forward, continuously
  attempt rebasing and pushing.

* `merge`: *Optional.* If pushing fails with non-fast-forward, continuously
  attempt to merge remote to local before pushing. Only one of `merge` or
  `rebase` can be provided, but not both.

* `returning`: *Optional.* When passing the `merge` flag, specify whether the
  merge commit or the original, unmerged commit should be passed as the output
  ref. Options are `merged` and `unmerged`. Defaults to `merged`.

* `tag`: *Optional.* If this is set then HEAD will be tagged. The value should be
  a path to a file containing the name of the tag.

* `only_tag`: *Optional.* When set to 'true' push only the tags of a repo.

* `tag_prefix`: *Optional.* If specified, the tag read from the file will be
prepended with this string. This is useful for adding `v` in front of
version numbers.

* `force`: *Optional.* When set to 'true' this will force the branch to be
pushed regardless of the upstream state.

* `annotate`: *Optional.* If specified the tag will be an
  [annotated](https://git-scm.com/book/en/v2/Git-Basics-Tagging#Annotated-Tags)
  tag rather than a
  [lightweight](https://git-scm.com/book/en/v2/Git-Basics-Tagging#Lightweight-Tags)
  tag. The value should be a path to a file containing the annotation message.

* `notes`: *Optional.* If this is set then notes will be added to HEAD to the
  `refs/notes/commits` ref. The value should be a path to a file containing the notes.

* `branch`: *Optional.* The branch to push commits.

  Note that the version produced by the `put` step will be picked up by subsequent `get` steps
  even if the `branch` differs from the `branch` specified in the source.
  To avoid this, you should use two resources of read-only and write-only.

* `refs_prefix`: *Optional.* Allows pushing to refs other than heads. Defaults to `refs/heads`.

  Useful when paired with `source.search_remote_refs` in cases where the git remote
  renames the ref you pushed.

## Development

### Prerequisites

* golang is *required* - version 1.9.x is tested; earlier versions may also
  work.
* docker is *required* - version 17.06.x is tested; earlier versions may also
  work.

### Running the tests

The tests have been embedded with the `Dockerfile`; ensuring that the testing
environment is consistent across any `docker` enabled platform. When the docker
image builds, the test are run inside the docker container, on failure they
will stop the build.

Run the tests with the following commands for both `alpine` and `ubuntu` images:

```sh
docker build -t git-resource --target tests -f dockerfiles/alpine/Dockerfile .
docker build -t git-resource --target tests -f dockerfiles/ubuntu/Dockerfile .
```

#### Note about the integration tests

If you want to run the integration tests, a bit more work is required. You will require
an actual git repo to which you can push and pull, configured for SSH access. To do this,
add two files to `integration-tests/ssh` (note that names **are** important):

* `test_key`: This is the private key used to authenticate against your repo.
* `test_repo`: This file contains one line of the form `test_repo_url[#test_branch]`.
  If the branch is not specified, it defaults to `master`. For example,
  `git@github.com:concourse-git-tester/git-resource-integration-tests.git` or
  `git@github.com:concourse-git-tester/git-resource-integration-tests.git#testing`

### Contributing

Please make all pull requests to the `master` branch and ensure tests pass
locally.
