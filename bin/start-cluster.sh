#! /bin/bash

set -e

if env | egrep -q "DOCKER_RIAK_CS_DEBUG"; then
  set -x
fi

if ! env | egrep -q "DOCKER_RIAK_CS_AUTOMATIC_CLUSTERING=1" && \
  env | egrep -q "DOCKER_RIAK_CS_HAPROXY=1"; then
  echo
  echo "It appears that you have enabled HAProxy support, but have"
  echo "not enabled automatic clustering. In order to use Riak and"
  echo "HAProxy, please enable automatic clustering."
  echo

  exit 1
fi

CLEAN_DOCKER_HOST=$(echo "${DOCKER_HOST}" | cut -d'/' -f3 | cut -d':' -f1)
CLEAN_DOCKER_HOST=${CLEAN_DOCKER_HOST:-localhost}
DOCKER_RIAK_CS_CLUSTER_SIZE=${DOCKER_RIAK_CS_CLUSTER_SIZE:-5}

if docker ps -a | egrep "hectcastro/riak" >/dev/null; then
  echo
  echo "It looks like you already have some Riak containers running."
  echo "Please take them down before attempting to bring up another"
  echo "cluster with the following command:"
  echo
  echo "  make stop-cluster"
  echo

  exit 1
fi

echo
echo "Bringing up cluster nodes:"
echo

for index in $(seq -w "1" "99");
do
  if [ "${index}" -gt "${DOCKER_RIAK_CS_CLUSTER_SIZE}" ] ; then
      break
  fi
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

  CONTAINER_ID=$(docker ps | egrep "riak-cs${index}" | cut -d" " -f1)
  CONTAINER_PORT=$(docker port "${CONTAINER_ID}" 8080 | cut -d ":" -f2)

  until curl -s "http://${CLEAN_DOCKER_HOST}:${CONTAINER_PORT}/riak-cs/ping" | egrep "OK" > /dev/null 2>&1;
  do
    sleep 3
  done

  echo "  Successfully brought up [riak-cs${index}]"
done

if env | egrep -q "DOCKER_RIAK_CS_HAPROXY=1"; then
  RIAK_CS_CONTAINER_LINKS=""

  for index in $(seq -w "1" "99");
  do
    if [ "${index}" -gt "${DOCKER_RIAK_CS_CLUSTER_SIZE}" ] ; then
      break
    fi
    RIAK_CS_CONTAINER_LINKS="${RIAK_CS_CONTAINER_LINKS}--link riak-cs${index}:riak-cs${index} "
  done

  eval docker run -p 8080:8080 -p 8888:8888 \
    "${RIAK_CS_CONTAINER_LINKS}"\
    --name "riak-cs-haproxy" -d hectcastro/riak-cs-haproxy > /dev/null 2>&1

  until curl -s "http://${CLEAN_DOCKER_HOST}:8080/riak-cs/ping" | egrep "OK" > /dev/null 2>&1;
  do
    sleep 3
  done

  echo "  Successfully brought up [riak-cs-haproxy]"
fi

INSECURE_KEY_FILE=.insecure_key
SSH_KEY_URL="https://github.com/phusion/baseimage-docker/raw/master/image/services/sshd/keys/insecure_key"
CS01_PORT=$(docker port riak-cs01 22 | cut -d':' -f2)

# Download insecure ssh key of phusion/baseimage-docker
if [ ! -f $INSECURE_KEY_FILE ]; then
  echo
  echo "  Downloading insecure SSH key..."

  if which curl > /dev/null; then
    curl -o .insecure_key -fSL $SSH_KEY_URL > /dev/null 2>&1
  elif which wget > /dev/null; then
    wget -O .insecure_key $SSH_KEY_URL > /dev/null 2>&1
  else
    echo "curl or wget is required to download insecure SSH key. Check"
    echo "the README to get more information about how to download it."
  fi
fi

if [ -f $INSECURE_KEY_FILE ]; then
  # SSH requires some constraints on private key permissions, force it!
  chmod 600 .insecure_key

  echo
  echo "  Riak CS credentials:"
  echo

  # If starting only one node we need to wait a litle bit for keys
  if [ ${DOCKER_RIAK_CS_CLUSTER_SIZE} -eq 1 ] ; then
      sleep 30
  fi

  for field in admin_key admin_secret ; do
    echo -n "    ${field}: "

    ssh -i "${INSECURE_KEY_FILE}" -o "LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" \
        -p "${CS01_PORT}" "root@${CLEAN_DOCKER_HOST}" egrep "${field}" /etc/riak-cs/app.config | cut -d'"' -f2
  done
fi

echo
echo "Please wait approximately 30 seconds for the cluster to stabilize."
echo
