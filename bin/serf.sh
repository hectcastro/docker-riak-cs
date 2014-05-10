#! /bin/sh

# Start Serf
if env | egrep -q "SEED_NAME"; then
  SERF_NODE_NAME=$(echo "$SEED_NAME" | cut -d"/" -f2)
  SERF_EVENT_HANDLER="peer-member-join.sh"
else
  SERF_NODE_NAME="riak-cs01"
  SERF_EVENT_HANDLER="seed-member-join.sh"
fi

exec /sbin/setuser serf /usr/bin/serf agent -node "${SERF_NODE_NAME}" -log-level=debug \
   -event-handler "/etc/service/serf/${SERF_EVENT_HANDLER}" >> /var/log/serf.log 2>&1
