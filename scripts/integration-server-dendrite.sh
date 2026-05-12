#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019-Present Famedly GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# creating integration test SSL certificates
docker run --rm --entrypoint="" \
  --volume="$(pwd)/test_driver/dendrite/data":/etc/dendrite:rw \
  matrixdotorg/dendrite-monolith:latest \
  /usr/bin/generate-keys \
  -private-key /etc/dendrite/matrix_key.pem \
  -tls-cert /etc/dendrite/server.crt \
  -tls-key /etc/dendrite/server.key

docker run -d --volume="$(pwd)/test_driver/dendrite/data":/etc/dendrite:rw \
  --name dendrite -p 80:8008 matrixdotorg/dendrite-monolith:latest -really-enable-open-registration
