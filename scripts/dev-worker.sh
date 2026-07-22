#!/usr/bin/env bash
# Launch a development worker so that changes in a dev
# environment can be refreshed
__dirname=$(cd "$(dirname "$0")"; pwd -P)
cd "$(dirname "${__dirname}")"

podman stop worker
podman-compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.dev.yml run --entrypoint bash worker
