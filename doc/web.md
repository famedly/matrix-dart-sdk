To use end to end encryption in web you have to download the olm javascript/wasm library:

```sh
#!/bin/sh -ve
rm -r assets/js/package

OLM_VERSION=$(cat pubspec.yaml | yq .dependencies.flutter_olm)
DOWNLOAD_PATH="https://github.com/famedly/olm/releases/download/v$OLM_VERSION/olm.zip"

curl -L $DOWNLOAD_PATH > olm.zip
unzip olm.zip
rm olm.zip
```

...and import it in your `index.html`:

```html
<html>
    <head>
        ...
        <script src="path/to/assets/olm.js"></script>
    </head>
    ...
</html>
```