#!/bin/bash

set -e

# Change to configured directory
cd "${DIRECTORY}"

# Make Token available as a correctly-named environment variables
export GH_TOKEN="${GITHUB_TOKEN}"

# Run Semantic Release
semantic-release ${ROOT_OPTIONS} publish --tag "${TAG}"
