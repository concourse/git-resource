# Git Resource

Tracks the commits in a [git](http://git-scm.com/) repository.

<a href="https://ci.concourse-ci.org/teams/main/pipelines/resource/jobs/build?vars.type=%22git%22">
  <img src="https://ci.concourse-ci.org/api/v1/teams/main/pipelines/resource/jobs/build/badge?vars.type=%22git%22" alt="Build Status">
</a>


## Source Configuration

<table>
  <tr>
    <th>Field Name</th>
    <th>Description</th>
  </tr>
  <tr>
    <td><code>uri</code> (Required)</td>
    <td>The location of the repository.</td>
  </tr>
  <tr>
    <td><code>branch</code> (Optional)</td>
    <td>
        The branch to track. This is optional if the resource is only used in
        <code>get</code> steps; however, it is required when used in a
        <code>put</code> step. If unset, <code>get</code> steps will checkout
        the repository's default branch; usually <code>master</code> but <a
        href="https://help.github.com/articles/setting-the-default-branch/">could
        be different</a>.
    </td>
  </tr>
  <tr>
    <td><code>private_key</code> (Optional)</td>
    <td>Private key to use when using an <code>ssh@</code> format <code>uri</code>. Example:
      <pre>
private_key: |
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----
      </pre>
    </td>
  </tr>
  <tr>
    <td><code>private_key_user</code> (Optional)</td>
    <td>Enables setting User in the ssh config.</td>
  </tr>
  <tr>
    <td><code>private_key_passphrase</code> (Optional)</td>
    <td>To unlock <code>private_key</code> if it is protected by a passphrase.</td>
  </tr>
  <tr>
    <td><code>forward_agent</code> (Optional)</td>
    <td>Enables ForwardAgent SSH option when set to true. Useful when using proxy/jump hosts. Defaults to false.</td>
  </tr>
  <tr>
    <td><code>username</code> (Optional)</td>
    <td>Username for HTTP(S) auth when pulling/pushing. This is needed when only HTTP/HTTPS protocol for git is available (which does not support private key auth) and auth is required.</td>
  </tr>
  <tr>
    <td><code>password</code> (Optional)</td>
    <td>Password for HTTP(S) auth when pulling/pushing.</td>
  </tr>
  <tr>
    <td><code>paths</code> (Optional)</td>
    <td>If specified (as a list of glob patterns), only changes to the specified files will yield new versions from <code>check</code>.</td>
  </tr>
  <tr>
    <td><code>sparse_paths</code> (Optional)</td>
    <td>
        If specified (as a list of glob patterns), only these paths will be
        checked out. Should be used with <code>paths</code> to only trigger on
        desired paths. <code>paths</code> and <code>sparse_paths</code> may be
        the same or you can configure <code>sparse_paths</code> to check out
        other paths.
    </td>
  </tr>
  <tr>
    <td><code>ignore_paths</code> (Optional)</td>
    <td>
        The inverse of <code>paths</code>; changes to the specified files are
        ignored. <p>Note that if you want to push commits that change these
        files via a <code>put</code>, the commit will still be "detected", as <a
        href="https://github.com/concourse/concourse/issues/534"><code>check</code>
        and <code>put</code> both introduce versions</a>. To avoid this you
        should define a second resource that you use for commits that change
        files that you don't want to feed back into your pipeline - think of one
        as read-only (with <code>ignore_paths</code>) and one as write-only
        (which shouldn't need it).</p>
    </td>
  </tr>
  <tr>
    <td><code>skip_ssl_verification</code> (Optional)</td>
    <td>Skips git ssl verification by exporting <code>GIT_SSL_NO_VERIFY=true</code>.</td>
  </tr>
  <tr>
    <td><code>tag_filter</code> (Optional)</td>
    <td>
        If specified, the resource will only detect commits that have a tag
        matching the expression that have been made against the
        <code>branch</code>. Patterns are <a
        href="http://man7.org/linux/man-pages/man7/glob.7.html">glob(7)</a>
        compatible (as in, bash compatible).
    </td>
  </tr>
  <tr>
    <td><code>tag_regex</code> (Optional)</td>
    <td>
        If specified, the resource will only detect commits that have a tag
        matching the expression that have been made against the
        <code>branch</code>. Patterns are <a
        href="https://www.gnu.org/software/grep/manual/grep.html">grep</a>
        compatible (extended matching enabled, matches entire lines only).
        Ignored if <code>tag_filter</code> is also specified.
    </td>
  </tr>
  <tr>
    <td><code>tag_behaviour</code> (Optional)</td>
    <td>
        If <code>match_tagged</code> (the default), then the resource will only
        detect commits that are tagged with a tag matching
        <code>tag_regex</code> and <code>tag_filter</code>, and match all other
        filters. If <code>match_tag_ancestors</code>, then the resource will
        only detect commits matching all other filters and that are ancestors of
        a commit that are tagged with a tag matching <code>tag_regex</code> and
        <code>tag_filter</code>.
    </td>
  </tr>
  <tr>
    <td><code>fetch_tags</code> (Optional)</td>
    <td>If <code>true</code> the flag <code>--tags</code> will be used to fetch all tags in the repository. If <code>false</code> no tags will be fetched.</td>
  </tr>
  <tr>
    <td><code>submodule_credentials</code> (Optional)</td>
    <td>List of credentials for HTTP(s) or SSH auth when pulling git submodules which are not stored in the same git server as the container repository or are protected by a different private key.
      <ul>
        <li>http(s) credentials:
          <ul>
            <li><code>host</code> : The host to connect too. Note that <code>host</code> is specified with no protocol extensions.</li>
            <li><code>username</code> : Username for HTTP(S) auth when pulling submodule.</li>
            <li><code>password</code> : Password for HTTP(S) auth when pulling submodule.</li>
          </ul>
        </li>
        <li>ssh credentials:
          <ul>
            <li><code>url</code> : Submodule url, as specified in the <code>.gitmodule</code> file. Support full or relative ssh url.</li>
            <li><code>private_key</code> : Private key for SSH auth when pulling submodule.</li>
            <li><code>private_key_passphrase</code> : <em>Optional.</em> To unlock <code>private_key</code> if it is protected by a passphrase.</li>
          </ul>
        </li>
        <li>example:
          <pre>
submodule_credentials:
  # http(s) credentials
- host: github.com
  username: git-user
  password: git-password
  # ssh credentials
- url: git@github.com:org-name/repo-name.git
  private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----
  private_key_passphrase: ssh-passphrase # (optional)
  # ssh credentials with relative url
- url: ../org-name/repo-name.git
  private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----
  private_key_passphrase: ssh-passphrase # (optional)
          </pre>
        </li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><code>git_config</code> (Optional)</td>
    <td>
        If specified as (list of pairs <code>name</code> and <code>value</code>) it will configure git global options, setting each name with each value.
        <p>This can be useful to set options like <code>credential.helper</code> or similar.</p>
        <p>See the <a href="https://www.kernel.org/pub/software/scm/git/docs/git-config.html"><code>git-config(1)</code> manual page</a> for more information and documentation of existing git options.</p>
    </td>
  </tr>
  <tr>
    <td><code>disable_ci_skip</code> (Optional)</td>
    <td>Allows for commits that have been labeled with <code>[ci skip]</code> or <code>[skip ci]</code> previously to be discovered by the resource.</td>
  </tr>
  <tr>
    <td><code>commit_verification_keys</code> (Optional)</td>
    <td>Array of GPG public keys that the resource will check against to verify the commit (details below).</td>
  </tr>
  <tr>
    <td><code>commit_verification_key_ids</code> (Optional)</td>
    <td>
        Array of GPG public key ids that the resource will check against to
        verify the commit (details below). The corresponding keys will be
        fetched from the key server specified in <code>gpg_keyserver</code>. The
        ids can be short id, long id or fingerprint.
    </td>
  </tr>
  <tr>
    <td><code>gpg_keyserver</code> (Optional)</td>
    <td>GPG keyserver to download the public keys from. Defaults to <code>hkp://keyserver.ubuntu.com/</code>.</td>
  </tr>
  <tr>
    <td><code>git_crypt_key</code> (Optional)</td>
    <td>
        Base64 encoded <a href="https://github.com/AGWA/git-crypt">git-crypt</a>
        key. Setting this will unlock / decrypt the repository with
        <code>git-crypt</code>. To get the key simply execute <code>git-crypt
        export-key -- - | base64</code> in an encrypted repository.
    </td>
  </tr>
  <tr>
    <td><code>https_tunnel</code> (Optional)</td>
    <td>Information about an HTTPS proxy that will be used to tunnel SSH-based git commands over. Has the following sub-properties:
      <ul>
        <li><code>proxy_host</code>: <em>Required.</em> The host name or IP of the proxy server</li>
        <li><code>proxy_port</code>: <em>Required.</em> The proxy server's listening port</li>
        <li><code>proxy_user</code>: <em>Optional.</em> If the proxy requires authentication, use this username</li>
        <li><code>proxy_password</code>: <em>Optional.</em> If the proxy requires authenticate, use this password</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><code>commit_filter</code> (Optional)</td>
    <td>Object containing commit message filters
      <ul>
        <li><code>exclude</code>: <em>Optional.</em> Array containing strings that should cause a commit to be skipped</li>
        <li><code>exclude_all_match</code>: <em>Optional.</em> Boolean wheater it should match all the exclude filters "AND", default: false</li>
        <li><code>include</code>: <em>Optional.</em> Array containing strings that <em>MUST</em> be included in commit messages for the commit to not be skipped</li>
        <li><code>include_all_match</code>: <em>Optional.</em> Boolean wheater it should match all the include filters "AND", default: false</li>
      </ul>
      <p><strong>Note</strong>: <em>You must escape any regex sensitive characters, since the string is used as a regex filter.</em> For example, using <code>[skip deploy]</code> or <code>[deploy skip]</code> to skip non-deployment related commits in a deployment pipeline:</p>
      <pre>
commit_filter:
  exclude: ["\\[skip deploy\\]", "\\[deploy skip\\]"]
      </pre>
    </td>
  </tr>
  <tr>
    <td><code>version_depth</code> (Optional)</td>
    <td>The number of versions to return when performing a check</td>
  </tr>
  <tr>
    <td><code>search_remote_refs</code> (Optional)</td>
    <td>
        True to search remote refs for the input version when checking out
        during the get step. This can be useful during the <code>get</code> step
        after a <code>put</code> step for unconventional workflows. One example
        workflow is the <code>refs/for/&lt;branch&gt;</code> workflow used by
        gerrit which 'magically' creates a <code>refs/changes/nnn</code>
        reference instead of the straight forward
        <code>refs/for/&lt;branch&gt;</code> reference that a git remote would
        usually create. See also <code>out params.refs_prefix</code>.
    </td>
  </tr>
</table>

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
      ...
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
      ...
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

* `.git/branch`: Name of the original branch that was cloned.

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

Run the tests with the following command:

```sh
docker build -t git-resource --target tests .
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
