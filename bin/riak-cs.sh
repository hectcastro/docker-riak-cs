#! /bin/sh

IP_ADDRESS=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)

# Ensure correct ownership and permissions on volumes
chown riakcs:riak /var/log/riak-cs
chmod 755 /var/log/riak-cs

# Open file descriptor limit
ulimit -n 4096

# Ensure the Erlang node name is set correctly
sed -i.bak "s/127.0.0.1/${IP_ADDRESS}/" /etc/riak-cs/vm.args

# Connect Riak CS instances to Stanchion
if env | egrep -q "SEED_PORT_8080_TCP_ADDR"; then
  sed -i.bak "s/{stanchion_ip, \"127.0.0.1\"},/{stanchion_ip, \"${SEED_PORT_8080_TCP_ADDR}\"},/" /etc/riak-cs/app.config
fi

# Start Riak CS
exec /sbin/setuser riakcs "$(ls -d /usr/lib/riak-cs/erts*)/bin/run_erl" "/tmp/riak-cs" \
   "/var/log/riak-cs" "exec /usr/sbin/riak-cs console"
