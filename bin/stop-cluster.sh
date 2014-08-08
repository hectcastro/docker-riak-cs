#! /bin/bash

set -e

if env | egrep -q "DOCKER_RIAK_CS_DEBUG"; then
  set -x
fi

docker ps | egrep "hectcastro/riak-cs" | cut -d" " -f1 | xargs docker rm -f > /dev/null 2>&1

echo "Stopped the cluster and cleared all of the running containers."
