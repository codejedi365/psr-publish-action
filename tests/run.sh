#!/bin/bash

set -e

# TODO: REmove --- temporary
realpath() {
    readlink -f "$1"
}

PROJ_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
EXAMPLE_PROJECT_BASE_DIR="${EXAMPLE_PROJECT_BASE_DIR:-"$PROJ_DIR/tests/example_project"}"

if [ -z "${UTILS_LOADED}" ]; then
    # shellcheck source=tests/utils.sh
    source "$PROJ_DIR/tests/utils.sh"
fi

create_example_project() {
    local EXAMPLE_PROJECT_DIR="$1"

    log "Creating example project in: $EXAMPLE_PROJECT_DIR"
    mkdir -vp "$(dirname "$EXAMPLE_PROJECT_DIR")"
    cp -r "${EXAMPLE_PROJECT_BASE_DIR}" "$EXAMPLE_PROJECT_DIR"

    pushd "$EXAMPLE_PROJECT_DIR" >/dev/null || return 1
    log "Constructing git history in repository"
    git init
    git add .
    git commit -m "Initial commit"
    git remote add origin "https://github.com/python-semantic-release/example-project.git"

    cat <<EOF >pyproject.toml
[project]
name = "example"
version = "1.0.0"
description = "Example project"
EOF
    git commit -am '1.0.0'
    git tag -a v1.0.0 -m "v1.0.0"

    popd >/dev/null || return 1
    log "Example project created successfully"
}

# ------------------------------
# TEST SUITE DRIVER
# ------------------------------

run_test_suite() {
    local ALL_TEST_FNS

    # Dynamically import all test scripts
    for test_script in "$PROJ_DIR"/tests/suite/test_*.sh; do
        if [ -f "$test_script" ]; then
            if ! source "$test_script"; then
                error "Failed to load test script: $test_script"
            fi
        fi
    done

    # Extract all test functions
    tests_in_env="$(compgen -A function | grep "^test_")"
    read -r -a ALL_TEST_FNS <<< "$(printf '%s' "$tests_in_env" | tr '\n' ' ')"

    log ""
    log "************************"
    log "*  Running test suite  *"
    log "************************"

    # Incrementally run all test functions and flag if any fail
    local test_index=1
    local test_failures=0
    for test_fn in "${ALL_TEST_FNS[@]}"; do
        if command -v "$test_fn" &>/dev/null; then
            if ! "$test_fn" "$test_index"; then
                ((test_failures++))
            fi
        fi
        log "--------------------------------------------------------------------------------"
        ((test_index++))
    done

    log ""
    log "************************"
    log "*     Test Summary     *"
    log "************************"
    log ""
    log "Total tests executed: ${#ALL_TEST_FNS[@]}"
    log "Successes: $((${#ALL_TEST_FNS[@]} - test_failures))"
    log "Failures: $test_failures"

    if [ "$test_failures" -gt 0 ]; then
        return 1
    fi
}

# ------------------------------
# MAIN
# ------------------------------

log "================================================================================"
log "||                          Publish Action Test Runner                        ||"
log "================================================================================"
log "Initializing..."

# Make absolute path to project directory
PROJECT_MOUNT_DIR="${PROJ_DIR:?}/${PROJECT_MOUNT_DIR:?}"

log ""
log "******************************"
log "*  Running test suite setup  *"
log "******************************"
log ""

# Setup project environment
create_example_project "$PROJECT_MOUNT_DIR"
trap 'rm -rf "${PROJECT_MOUNT_DIR:?}"' EXIT

run_test_suite
