# docker login --username=$DOCKER_USERNAME --password=$DOCKER_PASSWORD
docker buildx build --platform linux/amd64 -t opendoor/git-resource --build-arg base_image=paketobuildpacks/run-jammy-base:latest . --push
