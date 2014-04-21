#! /bin/sh

if env | egrep -q "DOCKER_RIAK_CS_AUTOMATIC_CLUSTERING=1"; then
  # Join node to the Riak and Serf clusters
  (sleep 5; if env | egrep -q "SEED_PORT_8080_TCP_ADDR"; then
    serf join "${SEED_PORT_8080_TCP_ADDR}" > /dev/null 2>&1
    riak-admin cluster join "riak@${SEED_PORT_8080_TCP_ADDR}" > /dev/null 2>&1
  fi) &

  # Are we the last node to join?
  (sleep 8; if riak-admin member-status | egrep "joining|valid" | wc -l | egrep -q "${DOCKER_RIAK_CS_CLUSTER_SIZE}"; then
    riak-admin cluster plan > /dev/null 2>&1 && riak-admin cluster commit > /dev/null 2>&1
  fi) &
fi
