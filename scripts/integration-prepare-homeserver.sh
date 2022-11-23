#!/usr/bin/env bash

IP_ADDRESS="$(drill docker | grep -m 1 -P "\d+\.\d+\.\d+.\d+" | awk -F ' ' '{print $NF}')"

echo "Homeserver IP found at $IP_ADDRESS."

echo "Waiting for homeserver to be available..."

while ! curl -XGET "http://$IP_ADDRESS/_matrix/client/v3/login" >/dev/null 2>/dev/null; do
  sleep 2
done
echo "Homeserver is up."

sed -i "s/localhost/$IP_ADDRESS/g" test_driver/test_config.dart

curl -XPOST -d '{"username":"alice", "password":"AliceInWonderland", "inhibit_login":true, "auth": {"type":"m.login.dummy"}}' "http://$IP_ADDRESS/_matrix/client/r0/register"
curl -XPOST -d '{"username":"bob", "password":"JoWirSchaffenDas", "inhibit_login":true, "auth": {"type":"m.login.dummy"}}' "http://$IP_ADDRESS/_matrix/client/r0/register"
curl -XPOST -d '{"username":"trudy", "password":"HaveIBeenPwned", "inhibit_login":true, "auth": {"type":"m.login.dummy"}}' "http://$IP_ADDRESS/_matrix/client/r0/register"
