# Opendoor's Concourse ResourceType : git-resource

## What does this provide over the original git-resource that was forked
* original: https://github.com/concourse/git-resource
* defaults the clone `depth` from `0` (not used) to `1`
* uses a json key called `source.githubApp` (for Github Applications)
* hides the token used in the `output` in the URL for security measures
* extra `logInfo` for debugging / information

## How do I build a resourceType
* https://concourse-ci.org/implementing-resource-types.html

## How do deploy this to DockerHub
* `buildAndPushDockerhub.sh`

## Sample pipeline
* https://github.com/opendoor-labs/code/tree/master/infra/sample-opendoor-git-resource
* https://concourse.managed.services.opendoor.com/teams/engineering/pipelines/sample-opendoor-git-resource/