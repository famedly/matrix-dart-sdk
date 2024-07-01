#!/usr/bin/env bash

docker run -d --rm --name synapse --tmpfs /data \
    --volume="$(pwd)/test_driver/synapse/data/homeserver.yaml":/data/homeserver.yaml:rw \
    --volume="$(pwd)/test_driver/synapse/data/localhost.log.config":/data/localhost.log.config:rw \
    -p 80:80 matrixdotorg/synapse:latest
