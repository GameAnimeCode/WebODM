#!/usr/bin/env bash
__dirname=$(cd "$(dirname "$0")"; pwd -P)
cd "$(dirname "${__dirname}")"

export COMPOSE_FILE=docker/compose/docker-compose.yml:docker/compose/docker-compose.build.yml
WAIT_SECONDS=20

# Function to run on script exit (success or failure)
cleanup() {
  echo "Cleaning up Podman environment..."
  podman-compose down -v --remove-orphans
}

# Register the cleanup function to run on script exit
trap cleanup EXIT

# Stop on first error for build and up
set -e

echo "Building and starting containers..."
podman-compose build --build-arg TEST_BUILD=ON
podman-compose up --wait

# Wait for services to be ready
echo "Waiting $WAIT_SECONDS seconds for services to initialize..."
sleep $WAIT_SECONDS

echo "Running tests..."
# Pass remaining arguments
podman-compose exec -T webapp /webodm/webodm.sh test "$@"

echo "Tests completed successfully!"
