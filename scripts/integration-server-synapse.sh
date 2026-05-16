#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019-Present Famedly GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

sudo chown -R 991:991 test_driver/synapse/data

docker run -d --name synapse \
    --volume="$(pwd)/test_driver/synapse/data":/data:rw \
    -p 80:80 matrixdotorg/synapse:latest
