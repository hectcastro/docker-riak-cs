# Riak CS
#
# VERSION       0.7.2

FROM phusion/baseimage:0.9.15
MAINTAINER Hector Castro hectcastro@gmail.com

# Environmental variables
ENV DEBIAN_FRONTEND noninteractive
ENV RIAK_VERSION 1.4.10
ENV RIAK_SHORT_VERSION 1.4
ENV RIAK_CS_VERSION 1.5.2
ENV RIAK_CS_SHORT_VERSION 1.5
ENV STANCHION_VERSION 1.5.0
ENV STANCHION_SHORT_VERSION 1.5
ENV SERF_VERSION 0.6.3

# Install dependencies
RUN apt-get update -qq && apt-get install unzip -y

# Install Riak
ADD http://s3.amazonaws.com/downloads.basho.com/riak/${RIAK_SHORT_VERSION}/${RIAK_VERSION}/ubuntu/precise/riak_${RIAK_VERSION}-1_amd64.deb /
RUN (cd / && dpkg -i "riak_${RIAK_VERSION}-1_amd64.deb")

# Setup the Riak service
RUN mkdir -p /etc/service/riak
ADD bin/riak.sh /etc/service/riak/run

# Install Riak CS
ADD http://s3.amazonaws.com/downloads.basho.com/riak-cs/${RIAK_CS_SHORT_VERSION}/${RIAK_CS_VERSION}/ubuntu/trusty/riak-cs_${RIAK_CS_VERSION}-1_amd64.deb /
RUN (cd / && dpkg -i "riak-cs_${RIAK_CS_VERSION}-1_amd64.deb")

# Setup the Riak CS service
RUN mkdir -p /etc/service/riak-cs
ADD bin/riak-cs.sh /etc/service/riak-cs/run

# Install Stanchion
ADD http://s3.amazonaws.com/downloads.basho.com/stanchion/${STANCHION_SHORT_VERSION}/${STANCHION_VERSION}/ubuntu/trusty/stanchion_${STANCHION_VERSION}-1_amd64.deb /
RUN (cd / && dpkg -i "stanchion_${STANCHION_VERSION}-1_amd64.deb")

# Setup the Stanchion service
RUN mkdir -p /etc/service/stanchion
ADD bin/stanchion.sh /etc/service/stanchion/run

# Setup automatic clustering for Riak
ADD bin/automatic_clustering.sh /etc/my_init.d/99_automatic_clustering.sh

# Install Serf
ADD https://releases.hashicorp.com/serf/${SERF_VERSION}/serf_${SERF_VERSION}_linux_amd64.zip /
RUN (cd / && unzip serf_${SERF_VERSION}_linux_amd64.zip -d /usr/bin/)

# Setup the Serf service
RUN mkdir -p /etc/service/serf && \
    adduser --system --disabled-password --no-create-home \
            --quiet --force-badname --shell /bin/bash --group serf && \
    echo "serf ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99_serf && \
    chmod 0440 /etc/sudoers.d/99_serf
ADD bin/serf.sh /etc/service/serf/run
ADD bin/peer-member-join.sh /etc/service/serf/
ADD bin/seed-member-join.sh /etc/service/serf/

# Tune Riak and Riak CS configuration settings for the container
ADD etc/riak-app.config /etc/riak/app.config
RUN sed -i.bak "s/riak_cs-VERSION/riak_cs-${RIAK_CS_VERSION}/" /etc/riak/app.config && \
    sed -i.bak 's/\"127.0.0.1\", 8098/\"0.0.0.0\", 8098/' /etc/riak/app.config && \
    sed -i.bak "s/-env ERL_MAX_PORTS 16384/-env ERL_MAX_PORTS 64000/" /etc/riak/vm.args && \
    sed -i.bak "s/##+zdbbl 32768/+zdbbl 96000/" /etc/riak/vm.args && \
    sed -i.bak "s/{cs_ip, \"127.0.0.1\"},/{cs_ip, \"0.0.0.0\"},/" /etc/riak-cs/app.config && \
    sed -i.bak "s/{fold_objects_for_list_keys, false},/{fold_objects_for_list_keys, true},/" /etc/riak-cs/app.config && \
    sed -i.bak "s/{anonymous_user_creation, false},/{anonymous_user_creation, true},/" /etc/riak-cs/app.config && \
    sed -i.bak "s/{stanchion_ip, \"127.0.0.1\"},/{stanchion_ip, \"0.0.0.0\"},/" /etc/stanchion/app.config

# Make the Riak, Riak CS, and Stanchion log directories into volumes
VOLUME /var/lib/riak
VOLUME /var/log/riak
VOLUME /var/log/riak-cs
VOLUME /var/log/stanchion

# Open the HTTP port for Riak and Riak CS (S3)
EXPOSE 8098 8080 22

# Enable insecure SSH key
# See: https://github.com/phusion/baseimage-docker#using_the_insecure_key_for_one_container_only
RUN /usr/sbin/enable_insecure_key

# Cleanup
RUN rm "/riak_${RIAK_VERSION}-1_amd64.deb" && \
    rm "/riak-cs_${RIAK_CS_VERSION}-1_amd64.deb" && \
    rm "/stanchion_${STANCHION_VERSION}-1_amd64.deb" && \
    rm "/serf_${SERF_VERSION}_linux_amd64.zip"
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Leverage the baseimage-docker init system
CMD ["/sbin/my_init", "--quiet"]
