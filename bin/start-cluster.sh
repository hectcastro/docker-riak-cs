#! /bin/bash

set -e

if env | egrep -q "DOCKER_RIAK_CS_DEBUG"; then
  set -x
fi

CLEAN_DOCKER_HOST=$(echo "${DOCKER_HOST}" | cut -d'/' -f3 | cut -d':' -f1)
DOCKER_RIAK_CS_CLUSTER_SIZE=${DOCKER_RIAK_CS_CLUSTER_SIZE:-5}

if docker ps -a | egrep "hectcastro/riak" >/dev/null; then
  echo ""
  echo "It looks like you already have some Riak containers running."
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

  until curl -s "http://${CLEAN_DOCKER_HOST}:${CONTAINER_PORT}/riak-cs/ping" | egrep "OK" > /dev/null 2>&1;
  do
    sleep 3
  done

  echo "  Successfully brought up [riak-cs${index}]"
done

echo
# Download insecure ssh key of phusion/baseimage-docker
INSECURE_KEY_FILE=.insecure_key
if [ ! -f $INSECURE_KEY_FILE ]; then
  SSH_KEY_URL="https://github.com/phusion/baseimage-docker/raw/master/image/insecure_key"
  echo "Downloading SSH insecure key..."
  if which curl > /dev/null; then
    curl -o .insecure_key -fSL $SSH_KEY_URL > /dev/null 2>&1
  elif which wget > /dev/null; then
    wget -O .insecure_key $SSH_KEY_URL > /dev/null 2>&1
  else
    echo "curl or wget required to download SSH insecure key"
    echo "Check the README to get more info about how to download this keys"
  fi
fi

if [ -f $INSECURE_KEY_FILE ]; then
  # SSH requires some constraints on private key permissions, force it!
  [ "$(stat --printf="%a\n" .insecure_key)" == "600" ] || chmod 600 .insecure_key
  CS01_IP=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' riak-cs01)
  for field in admin_key admin_secret ; do
    echo -n "$field: "
    ssh -i "$INSECURE_KEY_FILE" -o 'LogLevel=quiet' -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' root@"$CS01_IP" egrep "$field" /etc/riak-cs/app.config | cut -d'"' -f2
  done
fi

echo
echo "Please wait approximately 30 seconds for the cluster to stabilize."
echo
