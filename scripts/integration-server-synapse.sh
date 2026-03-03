#!/usr/bin/env bash

sudo chown -R 991:991 test_driver/synapse/data

docker run -d --name synapse \
    --volume="$(pwd)/test_driver/synapse/data":/data:rw \
    -p 80:80 matrixdotorg/synapse:latest
