# kubernetes on swarm on digitalocean

An experiment of kubernetes running on docker swarm running on DigitalOcean.


## Requirements

`swarm.sh` currently uses docker-machine.

## Usage

Start swarm up:

`./swarm.sh -n cluster01 -t <do token> up`

Shut swarm down:

`./swarm.sh -n cluster01 down`

Boot kubernetes

`docker-compose --x-networking -f k8s-swarm.yml up`


**warning** This script spins up DigitalOcean Droplets which may incur a cost.


Based on [https://github.com/docker/swarm-frontends](https://github.com/docker/swarm-frontends).
