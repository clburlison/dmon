# dmon (Device Monitor)

> :construction_worker: :hammer: **Work in progress. This is very much beta.** :construction: :vertical_traffic_light:

A monitor solution for jailbroken iOS devices. The core goal of this project is to make sure a specific iOS application is constantly running without needed to use Single App Mode (SAM) or Guided Access Mode (GAM).

A `setup` script is included to help with initial configuration of a jailbroken device.

Lastly, in the future I would like to include a way to handle updates for the various components.

## Monitor only

If you only care about the monitoring component from this repo you can grab the latest compiled `.deb` from the [Release page](https://github.com/clburlison/dmon/releases)

1. Grab the latest `com.github.clburlison.dmon-XXX.deb`
1. Copy it to your iOS device
1. Run `dpkg -i com.github.clburlison.dmon-XXX.deb`
1. The LaunchDaemon service will now monitor to make sure all components are properly running

## Getting started

It is assumed you know your way around a command line. All commands are run on your computer connected to a single iOS device. While it is possible to do some of this manually on a jailbroken iOS device that is pron to human error.

1. Grab a valid iOS 14+ device and jailbreak it: https://ios.cfw.guide/get-started/select-iphone/
1. Clone this git repo

   ```sh
   git clone https://github.com/clburlison/dmon
   ```

1. Change directory into the freshly cloned repo

   ```sh
   cd dmon
   ```

1. Create a `config.json` at the root of this repo with the correct values

   ```json
   {
     "api_key": "YOUR_GC_API_KEY",
     "device_configuration_manager_url": "https://my_awesome_DCM_url"
   }
   ```

1. Download any extra .deb files you want installed into the `./debs/` directory. These are installed based on file name IE 01_foobar.deb, 02_curl.deb, etc.

   > Substitute is installed as part of the `setup` script

   debs to include:

   - https://repo.spooferpro.com/debs/com.spooferpro.kernbypass_1.1.0_iphoneos-arm64.deb
   - Potentially any paid/private debs. nudge, nudge, wink, wink
   - (Optional) https://cydia.akemi.ai/debs/nodelete-ai.akemi.appsyncunified.deb
   - (Optional) https://cydia.akemi.ai/debs/nodelete-ai.akemi.appinst.deb

1. Grab a copy of Pokemon Go via [majd/ipatool](https://github.com/majd/ipatool)

   ```sh
   brew tap majd/repo
   brew install ipatool
   ipatool auth login -e 'youremail@example.com' -p 'PASSWORD'
   ipatool download --purchase -b com.nianticlabs.pokemongo -o pogo.ipa
   ```

1. Connect your iOS device to your computer via USB
1. Open Terminal and run (remember to only have one phone connected)

   ```sh
   # Alteratively you can pass -u <device-uuid> if multiple phones are connected
   iproxy 2222 22
   ```

1. Then in a separate terminal window run:

   ```sh
   ssh root@localhost -p 2222 # default password is 'alpine'
   ```

1. In a third terminal window run:

   ```sh
   ./setup
   ```

1. Assuming everything worked correctly your phone should be properly configured.

Bonus items that are out of scope for this project.

- Configure your device as supervised and push a wireless mobileconfig profile
- Configure your device to use Shared Internet from your mac
- Supervise your device and push a global proxy to route requests through HAproxy

## Tested

- All testing has been completed with iOS 15 using palera1n
- Only confirmed on older A9 processors aka iPhone SE first gen
- DEB Package is build on macOS Ventura

## References

- [dm.pl](https://github.com/theos/dm.pl)
- [appknox/Open](https://github.com/appknox/Open) which was originally from [conradev/Open](https://github.com/conradev/Open)
