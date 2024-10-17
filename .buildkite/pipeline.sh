#!/usr/bin/env bash
set -u

REPOSITORY="authelia/crossbuild"
TAG="latest"

cat << EOF
steps:
  - label: ":docker: Build and Deploy"
    commands:
      - "docker build --tag ${REPOSITORY}:${TAG} --provenance mode=max,reproducible=true --sbom true --builder buildx --progress plain --pull --push ."
    concurrency: 1
    concurrency_group: "crossbuild-deployments"
    agents:
      upload: "fast"

  - wait:

  - label: ":docker: Update README.md"
    command: "curl \"https://ci.nerv.com.au/readmesync/update?github_repo=${REPOSITORY}&dockerhub_repo=${REPOSITORY}\""
    agents:
      upload: "fast"
EOF