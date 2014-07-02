## 0.3.0

* Bump Riak version to `1.4.9`.
* Bump `phusion/baseimage` version to `0.9.11`.
* Bump Serf version to `0.6.2`.
* Default Docker port is now `2375`.
* Ensure host contained in `DOCKER_HOST` is used to detect node liveness.

## 0.2.0

* Remove `sysctl` specific settings from `Dockerfile`.
* Add better detection of an invalid cluster start state.
* Fix broken conditional for peer vs. seed Serf event handler script.

## 0.1.2

* Fix broken `test-cluster` target.

## 0.1.1

* Include a minimum Docker version requirement (`0.10.0`).

## 0.1.0

* Initial release.
