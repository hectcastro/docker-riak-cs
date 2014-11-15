# docker-riak-cs [![Build Status](https://secure.travis-ci.org/hectcastro/docker-riak-cs.png?branch=develop)](http://travis-ci.org/hectcastro/docker-riak-cs)

This is a [Docker](http://docker.io) project to bring up a local
[Riak CS](https://github.com/basho/riak_cs) cluster.

## Prerequisites

### Install Docker

Follow the [instructions on Docker's website](https://www.docker.io/gettingstarted/#h_installation)
to install Docker 0.10.0+.

From there, ensure that your `DOCKER_HOST` environmental variable is set
correctly:

```bash
$ export DOCKER_HOST="tcp://192.168.59.103:2375"
```

**Note:** If you're using [boot2docker](https://github.com/boot2docker/boot2docker)
ensure that you forward the virtual machine port range (`49000-49900`, `8080`,
`8888`). This
will allow you to interact with the containers as if they were running
locally:

```bash
$ for i in {49000..49900}; do
 VBoxManage modifyvm "boot2docker-vm" --natpf1 "tcp-port$i,tcp,,$i,,$i";
 VBoxManage modifyvm "boot2docker-vm" --natpf1 "udp-port$i,udp,,$i,,$i";
done
$ for i in {8080,8888}; do
 VBoxManage modifyvm "boot2docker-vm" --natpf1 "tcp-port$i,tcp,,$i,,$i";
 VBoxManage modifyvm "boot2docker-vm" --natpf1 "udp-port$i,udp,,$i,,$i";
done
```

### `sysctl`

In order to tune the Docker host housing Riak containers, consider applying
the following `sysctl` settings:

```
vm.swappiness = 0
net.ipv4.tcp_max_syn_backlog = 40000
net.core.somaxconn = 40000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_moderate_rcvbuf = 1
```

### `riak-cs-haproxy`

In order to interact with the entire cluster through one endpoint, the
`DOCKER_RIAK_CS_HAPROXY` environmental variable makes use of the
[hectcastro/riak-cs-haproxy](https://github.com/hectcastro/docker-riak-cs-haproxy)
image. This image automatically load balances incoming HTTP requests to port
`8080` against linked Riak CS containers.

## Running

### Clone repository and build Riak CS image

```bash
$ git clone https://github.com/hectcastro/docker-riak-cs.git
$ cd docker-riak-cs
$ make build
```

### Environmental variables

- `DOCKER_RIAK_CS_CLUSTER_SIZE` – The number of nodes in your Riak CS cluster
  (default: `5`)
- `DOCKER_RIAK_CS_AUTOMATIC_CLUSTERING` – A flag to automatically cluster Riak
  (default: `false`)
- `DOCKER_RIAK_CS_HAPROXY` - Enable an HAProxy container to load balance requests
  against all Riak CS nodes (default: `false`)
- `DOCKER_RIAK_CS_DEBUG` – A flag to `set -x` on the cluster management scripts
  (default: `false`)

### Launch cluster

```bash
$ DOCKER_RIAK_CS_HAPROXY=1 DOCKER_RIAK_CS_AUTOMATIC_CLUSTERING=1 DOCKER_RIAK_CS_CLUSTER_SIZE=5 make start-cluster
./bin/start-cluster.sh

Bringing up cluster nodes:

  Successfully brought up [riak-cs01]
  Successfully brought up [riak-cs02]
  Successfully brought up [riak-cs03]
  Successfully brought up [riak-cs04]
  Successfully brought up [riak-cs05]
  Successfully brought up [riak-cs-haproxy]

  Riak CS credentials:

    admin_key: VA4H7GSPO1J0NKMYT-TJ
    admin_secret: GvaJALz20W4-Xb330SBft8kPK3d-KKgG4fAMdA==

Please wait approximately 30 seconds for the cluster to stabilize.
```

## Testing

From outside the container, we can interact with the HTTP interfaces of Riak
and Riak CS. Additionally, the Riak CS HTTP interface supports an
[Amazon S3](http://docs.basho.com/riakcs/latest/references/apis/storage/s3/) or
[OpenStack Swift](http://docs.basho.com/riakcs/latest/references/apis/storage/openstack/)
compatible API.

### Riak HTTP

Riak's HTTP interface has an endpoint called `/stats` that emits Riak
statistics. The `test-cluster` `Makefile` target hits a random container's
`/stats` endpoint and pretty-prints its output to the console.

The most interesting attributes for testing cluster membership are
`ring_members`:

```bash
$ make test-cluster | egrep -A6 "ring_members"
    "ring_members": [
        "riak@172.17.0.2",
        "riak@172.17.0.3",
        "riak@172.17.0.4",
        "riak@172.17.0.5",
        "riak@172.17.0.6"
    ],
```

And `ring_ownership`:

```bash
$ make test-cluster | egrep "ring_ownership"
    "ring_ownership": "[{'riak@172.17.0.20',3},\n {'riak@172.17.0.10',4},\n {'riak@172.17.0.21',3},\n {'riak@172.17.0.11',4},\n {'riak@172.17.0.2',3},\n {'riak@172.17.0.12',4},\n {'riak@172.17.0.3',3},\n {'riak@172.17.0.13',4},\n {'riak@172.17.0.4',3},\n {'riak@172.17.0.14',3},\n {'riak@172.17.0.5',3},\n {'riak@172.17.0.15',3},\n {'riak@172.17.0.6',3},\n {'riak@172.17.0.16',3},\n {'riak@172.17.0.7',3},\n {'riak@172.17.0.17',3},\n {'riak@172.17.0.8',3},\n {'riak@172.17.0.18',3},\n {'riak@172.17.0.9',3},\n {'riak@172.17.0.19',3}]",
```

Together, these attributes let us know that this particular Riak node knows
about all of the other Riak instances.

### Amazon S3

`s3cmd` is convenient command-line tool to test the Riak CS Amazon S3
compatible API. Unfortunately, there is no easy way to extract the `admin_key`
and `admin_secret` needed for `s3cmd` to connect to the cluster.

First, we have to SSH into one of the Riak CS containers (see
[SSH section](#ssh) below for details):

```bash
$ ssh -i .insecure_key root@172.17.0.2
```

Next, we extract the `admin_key` and `admin_secret` from the Riak CS
configuration file:

```
root@90caa115f34f:~# egrep "admin_key" /etc/riak-cs/app.config | cut -d'"' -f2
AU4RL35KFK4N1EFTA0LO
root@90caa115f34f:~# egrep "admin_secret" /etc/riak-cs/app.config | cut -d'"' -f2
9EXxoSTLzrJFkwBDk2lijWiQiSeSa3o7eZOQ-w==
```

Then, we need to the port mappings for `8080`. For example, here's how to get
the port mapping for `riak-cs01`:

```
root@90caa115f34f:~# exit
$ docker port riak-cs01 8080 | cut -d":" -f2
49158
```

Now we have everything needed to connect to the cluster with `s3cmd`:

```
$ s3cmd --configure

Enter new values or accept defaults in brackets with Enter.
Refer to user manual for detailed description of all options.

Access key and Secret key are your identifiers for Amazon S3
Access Key: AU4RL35KFK4N1EFTA0LO
Secret Key: 9EXxoSTLzrJFkwBDk2lijWiQiSeSa3o7eZOQ-w==

Encryption password is used to protect your files from reading
by unauthorized persons while in transfer to S3
Encryption password:
Path to GPG program [/usr/local/bin/gpg]:

When using secure HTTPS protocol all communication with Amazon S3
servers is protected from 3rd party eavesdropping. This method is
slower than plain HTTP and can't be used if you're behind a proxy
Use HTTPS protocol [No]:

On some networks all internet access must go through a HTTP proxy.
Try setting it here if you can't conect to S3 directly
HTTP Proxy server name: localhost
HTTP Proxy server port [3128]: 49158

New settings:
  Access Key: AU4RL35KFK4N1EFTA0LO
  Secret Key: 9EXxoSTLzrJFkwBDk2lijWiQiSeSa3o7eZOQ-w==
  Encryption password:
  Path to GPG program: /usr/local/bin/gpg
  Use HTTPS protocol: False
  HTTP Proxy server name: localhost
  HTTP Proxy server port: 49158

Test access with supplied credentials? [Y/n] y
Please wait...
Success. Your access key and secret key worked fine :-)

Now verifying that encryption works...
Not configured. Never mind.

Save settings? [y/N] y
Configuration saved to '/Users/hector/.s3cfg'
```

### SSH

The [phusion/baseimage-docker](https://github.com/phusion/baseimage-docker)
image has the ability to enable an __insecure__ key for conveniently logging
into a container via SSH. It is enabled in the `Dockerfile` by default here:

```docker
RUN /usr/sbin/enable_insecure_key
```

In order to login to the container via SSH using the __insecure__ key, follow
the steps below.

Use `docker inspect` to determine the container IP address:

```bash
$ docker inspect $CONTAINER_ID | egrep IPAddress
        "IPAddress": "172.17.0.2",
```

Download the insecure key and alter its permissions:

```bash
$ curl -o insecure_key -fSL https://github.com/phusion/baseimage-docker/raw/master/image/insecure_key
$ chmod 600 insecure_key
```

**Note:** If you started a cluster, the insecure key has already been downloaded as `.insecure_key`.

Next, use the key to SSH into the container via its IP address:

```bash
$ ssh -i insecure_key root@172.17.0.2
```

**Note:** If you're using
[boot2docker](https://github.com/boot2docker/boot2docker), ensure that you're
issuing the SSH command from within the virtual machine running `boot2docker`.

## Destroying

```bash
$ make stop-cluster
./bin/stop-cluster.sh
Stopped the cluster and cleared all of the running containers.
```
