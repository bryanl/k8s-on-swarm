#!/usr/bin/env bash

set -e



up() {
  export DIGITALOCEAN_SIZE=4gb

  # change the ubuntu mirror to not DO mirrors.
  export DIGITALOCEAN_USERDATA='cloud-config.yml'

  echo "booting swarm: $name in $region"

  if [[ $(checkNode "$name-kvstore") == "1" ]]; then
    echo "creating keystore droplet"
    docker-machine $debug_mode create -d digitalocean --digitalocean-region $region $name-kvstore 
    docker $(docker-machine config $name-kvstore) run -d --net=host progrium/consul --server -bootstrap-expect 1
  fi

  kvip=$(docker-machine ip $name-kvstore)

  if [[ $(checkNode "$name-master") == "1" ]]; then
    echo "creating master droplet"
    docker-machine $debug_mode create -d digitalocean --digitalocean-region $region \
      --swarm --swarm-master --swarm-discovery consul://${kvip}:8500 \
      --engine-opt "cluster-store consul://${kvip}:8500" \
      --engine-opt "cluster-advertise eth0:2376" $name-master 

    if [[ $? != 0 ]]; then
      echo "couldn't create master"
      exit 1
    fi
  fi

  for i in $(seq 1 $node_count); do 
    node=$(printf "%s-%s-%02d" $name $region $i)

    if [[ $(checkNode "$node") != "1" ]]; then
      echo "skipping $node"
      continue
    fi

    echo "creating droplet node: $node"
    docker-machine $debug_mode create -d digitalocean --digitalocean-region $region \
      --swarm --swarm-discovery consul://${kvip}:8500 \
      --engine-label region=$region \
      --engine-opt "cluster-store consul://${kvip}:8500" \
      --engine-opt "cluster-advertise eth0:2376" $node &
  done

  wait

  eval $(docker-machine env --swarm $name-master)
  docker network ls
}

checkNode() {
  docker-machine status $1 &> /dev/null
  echo $?
}

down() {
  echo "removing cluster $name"
  docker-machine ls | awk '{print $1}' | grep $name | xargs docker-machine rm -f
}

usage() {
  echo "usage: $0 [-c <node count>] [-d] [-n <cluster name>] [-r <region>] [-t <do token>]"
  exit 0
}

# defaults
name="swarm"
region="nyc1"
node_count=3

while getopts ":c:dn:r:t" opt; do
  case "${opt}" in
    c)
      node_count=${OPTARG}
      ;;

    d)
      debug_mode="-D"
      ;;

    n)
      name=${OPTARG}
      ;;

    r)
      region=${OPTARG}
      ;;

    t)
      export DIGITALOCEAN_ACCESS_TOKEN=${OPTARG}
      ;;

    *)
      usage
      ;;
  esac
done

if [[ $DIGITALOCEAN_ACCESS_TOKEN == "" ]]; then
  echo "please supply DIGITALOCEAN_ACCESS_TOKEN environment variable or the -t option"
  exit 1
fi

shift $((OPTIND-1))
action="$1"; shift

case $action in
  up)
    up $@
    ;;
  down)
    down
    ;;
  *)
    echo "don't know how to $1"
    exit 1
    ;;
esac

