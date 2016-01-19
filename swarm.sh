#!/usr/bin/env bash

set -e

name="${2:-swarm}"

if [[ $DEBUG_SWARM == "1" ]]; then
  echo "debug mode"
fi

up() {
  export DIGITALOCEAN_ACCESS_TOKEN=$DO_PAT
  export DIGITALOCEAN_SIZE=4gb
  export DIGITALOCEAN_USERDATA='cloud-config.yml'


  echo "booting swarm: $name"

  if [[ $(checkNode "$name-kvstore") == "1" ]]; then
    echo "creating keystore"
    docker-machine -D create -d digitalocean --digitalocean-region tor1 $name-kvstore
    docker $(docker-machine config $name-kvstore) run -d --net=host progrium/consul --server -bootstrap-expect 1
  fi

  kvip=$(docker-machine ip $name-kvstore)

  if [[ $(checkNode "$name-master") == "1" ]]; then
    echo "creating master"
    docker-machine -D create -d digitalocean --digitalocean-region tor1 \
      --swarm --swarm-master --swarm-discovery consul://${kvip}:8500 \
      --engine-opt "cluster-store consul://${kvip}:8500" \
      --engine-opt "cluster-advertise eth0:2376" $name-master
  fi

  for region in nyc1 nyc2 nyc3 tor1 sfo1; do
    for i in {1..3}; do 
      node=$(printf "%s-%s-%02d" $name $region $i)

      if [[ $(checkNode "$node") != "1" ]]; then
        echo "skipping $node"
        continue
      fi

      echo "creating node: $node"
      docker-machine -D create -d digitalocean --digitalocean-region $region \
        --swarm --swarm-discovery consul://${kvip}:8500 \
        --engine-label region=$region
        --engine-opt "cluster-store consul://${kvip}:8500" \
        --engine-opt "cluster-advertise eth0:2376" $node
    done
  done

  eval $(docker-machine env --swarm $name-master)
  docker network ls
}

checkNode() {
  docker-machine status $1 > /dev/null
  echo $?
}

down() {
  docker-machine ls | grep $name | awk '{print $1}' | xargs docker-machine rm -f
}

case $1 in
  up)
    up
    ;;
  down)
    down
    ;;
  *)
    echo "don't know how to $1"
    exit 1
    ;;
esac

