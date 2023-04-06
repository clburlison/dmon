## Build steps for tools

```sh
export THEOS=./theos
git clone https://github.com/theos/theos.git $THEOS
curl -L -o /tmp/sdks.zip https://github.com/theos/sdks/archive/refs/heads/master.zip
unzip /tmp/sdks.zip -d $THEOS/sdks/
$THEOS/bin/update-theos
# To compile
# make
```

# dmon

We are using cURL which means external libraries are required (woo fun). You can download the pre-build binaries from https://github.com/jasonacox/Build-OpenSSL-cURL/releases

Untar the file and copy

```
# Steps from memory someone should review this. Might be able to use the lib/iOS builds. :shrug: idk what the difference is.
tar xf libcurl-8.0.1-openssl-1.1.1t-nghttp2-1.52.0.tgz
cp ./libcurl-8.0.1-openssl-1.1.1t-nghttp2-1.52.0/lib/iOS-fat/{libcrypto.a,libcurl.a,libnghttp2.a,libssl.a} ./theos/lib/
```

then grab the header files

```
# Also from memory
cp ./libcurl-8.0.1-openssl-1.1.1t-nghttp2-1.52.0/include/* ./theos/include/
```
