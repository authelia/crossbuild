#!/usr/bin/env bash
set -u

REPOSITORY="authelia/crossbuild"

if [[ ${BUILDKITE_BRANCH} == "master" ]]; then
  TAG="latest"
else
  TAG=${BUILDKITE_BRANCH}
fi

cat << EOF
steps:
  - label: ":docker: Build and Deploy"
    commands:
      - "docker build --tag ${REPOSITORY}:${TAG} --provenance mode=max,reproducible=true --sbom true --builder buildx --progress plain --pull --push ."
    concurrency: 1
    concurrency_group: "crossbuild-deployments"
    agents:
      upload: "fast"
    if: build.branch == "master"

  - label: ":docker: Build and Deploy"
    commands:
      - "docker build --tag ${REPOSITORY}:${TAG} --provenance mode=max,reproducible=true --sbom true --builder buildx --progress plain --pull --push ."
    agents:
      upload: "fast"
    if: build.branch != "master"

  - wait:
    if: build.branch == "master"

  - label: ":docker: Update README.md"
    command: "curl \"https://ci.nerv.com.au/readmesync/update?github_repo=${REPOSITORY}&dockerhub_repo=${REPOSITORY}\""
    agents:
      upload: "fast"
    if: build.branch == "master"
EOF