#! /bin/sh

# Start Serf
if env | egrep -q "SEED_NAME"; then
  SERF_NODE_NAME=$(echo "$SEED_NAME" | cut -d"/" -f2)
else
  SERF_NODE_NAME="riak-cs01"
fi

exec /sbin/setuser serf /usr/bin/serf agent -node "${SERF_NODE_NAME}" \
   -event-handler=/etc/service/serf/peer-member-join.sh >> /var/log/serf.log 2>&1
