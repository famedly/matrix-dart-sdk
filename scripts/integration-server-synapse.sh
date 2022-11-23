#!/usr/bin/env bash
chown -R 991:991 test_driver/synapse
docker run -d --name synapse --user 991:991 --volume="$(pwd)/test_driver/synapse/data":/data:rw -p 80:80 matrixdotorg/synapse:latest
