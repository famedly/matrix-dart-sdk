#!/usr/bin/env bash
chown -R 991:991 test_driver/dendrite

# creating integration test SSL certificates
docker run --rm --entrypoint="" \
  --volume="$(pwd)/test_driver/dendrite/data":/mnt:rw \
  matrixdotorg/dendrite-monolith:latest \
  /usr/bin/generate-keys \
  -private-key /mnt/matrix_key.pem \
  -tls-cert /mnt/server.crt \
  -tls-key /mnt/server.key

docker run -d --volume="$(pwd)/test_driver/dendrite/data":/etc/dendrite:rw \
  --name dendrite $NETWORK -p 80:8008 matrixdotorg/dendrite-monolith:latest -really-enable-open-registration
