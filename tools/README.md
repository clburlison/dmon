# tools

Open was forked from https://github.com/appknox/Open. It allows you to open apps from the commandline.

Usage: open [bundle_identifier]

    ```sh
    #Example: Launching Safari
    open com.apple.mobilesafari

    #Example: Launching Pokemon Go
    open com.nianticlabs.pokemongo
    ```

## Build steps for tools

    ```sh
    export THEOS=./theos
    git clone https://github.com/theos/theos.git $THEOS
    curl -L -o /tmp/sdks.zip https://github.com/theos/sdks/archive/refs/heads/master.zip
    unzip /tmp/sdks.zip -d $THEOS/sdks/
    $THEOS/bin/update-theos
    make open
    ```
