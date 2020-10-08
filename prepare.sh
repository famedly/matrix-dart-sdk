#!/bin/sh

mkdir js
cd js
curl -O 'https://packages.matrix.org/npm/olm/olm-3.1.4.tgz'
tar xaf olm-3.1.4.tgz
cd ..

if [ -f /usr/lib/x86_64-linux-gnu/libolm.so.3 ]
then
mkdir -p ffi/olm/
ln -sf /usr/lib/x86_64-linux-gnu/libolm.so.3 ffi/olm/libolm.so
else
cd ffi
pushd ffi
git clone --depth 1 https://gitlab.matrix.org/matrix-org/olm.git
cd olm
cmake -DCMAKE_BUILD_TYPE=Release .
cmake --build .
cd ..
fi

if which flutter >/dev/null; then
    flutter pub get
else
    pub get
fi
