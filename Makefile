.PHONY: all build riak-cs-container start-cluster test-cluster stop-cluster

all: stop-cluster riak-cs-container start-cluster

build riak-cs-container:
	docker build -t "hectcastro/riak-cs" .

start-cluster:
	./bin/start-cluster.sh

test-cluster:
	./bin/test-cluster.sh

stop-cluster:
	./bin/stop-cluster.sh
