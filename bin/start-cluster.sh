#! /bin/bash

set -e

if env | egrep -q "DOCKER_RIAK_CS_DEBUG"; then
  set -x
fi

DOCKER_RIAK_CS_CLUSTER_SIZE=${DOCKER_RIAK_CS_CLUSTER_SIZE:-5}

if docker ps | egrep "hectcastro/riak" >/dev/null; then
  echo ""
  echo "It looks like you already have some containers running."
  echo "Please take them down before attempting to bring up another"
  echo "cluster with the following command:"
  echo ""
  echo "  make stop-cluster"
  echo ""

  exit 1
fi

echo
echo "Bringing up cluster nodes:"
echo

for index in $(seq -f "%02g" "1" "${DOCKER_RIAK_CS_CLUSTER_SIZE}");
do
  if [ "${index}" -gt "1" ] ; then
    docker run -e "DOCKER_RIAK_CS_CLUSTER_SIZE=${DOCKER_RIAK_CS_CLUSTER_SIZE}" \
               -e "DOCKER_RIAK_CS_AUTOMATIC_CLUSTERING=${DOCKER_RIAK_CS_AUTOMATIC_CLUSTERING}" \
               -P --name "riak-cs${index}" --link "riak-cs01:seed" \
               -d hectcastro/riak-cs > /dev/null 2>&1
  else
    docker run -e "DOCKER_RIAK_CS_CLUSTER_SIZE=${DOCKER_RIAK_CS_CLUSTER_SIZE}" \
               -e "DOCKER_RIAK_CS_AUTOMATIC_CLUSTERING=${DOCKER_RIAK_CS_AUTOMATIC_CLUSTERING}" \
               -P --name "riak-cs${index}" -d hectcastro/riak-cs > /dev/null 2>&1
  fi

  CONTAINER_ID=$(docker ps | egrep "riak-cs${index}[^/]" | cut -d" " -f1)
  CONTAINER_PORT=$(docker port "${CONTAINER_ID}" 8080 | cut -d ":" -f2)

  until curl -s "http://localhost:${CONTAINER_PORT}/riak-cs/ping" | egrep "OK" > /dev/null 2>&1;
  do
    sleep 3
  done

  echo "  Successfully brought up [riak-cs${index}]"
done

echo
echo "Please wait approximately 30 seconds for the cluster to stabilize."
echo
