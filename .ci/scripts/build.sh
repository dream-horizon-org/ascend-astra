#!/usr/bin/env bash

set -e

main () {
  local artifact_name=$1

  mkdir -p target/"${artifact_name}"

  # copy plugins
  cp -r plugins .lua-format README.md target/"${artifact_name}"/

  # copy env, rock-spec & kong file
  cp "${artifact_name}"/.env target/"${artifact_name}"/
  cp "${artifact_name}"/kong.yaml target/"${artifact_name}"/
  cp "${artifact_name}"/*.rockspec target/"${artifact_name}"/
}

main "$@"
