# dmon (Device Monitor)

> :construction_worker: :hammer: **Work in progress** :construction: :vertical_traffic_light:

dmon is a monitor solution for jailbroken iOS devices. This project's core goal is to ensure a specific iOS application is constantly running without needing to use Single App Mode (SAM) or Guided Access Mode (GAM).

A script is included to help with the initial configuration of a jailbroken device: `./bin/setup`

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Testing](#testing)
- [Commonly asked questions](#commonly-asked-questions)
  - [Why didn't you use Theos to build the deb](#why-didnt-you-use-theos-to-build-the-deb)
  - [How do I stop it?](#how-can-i-stop-it)
  - [How do I set up the webserver?](#how-do-i-setup-the-webserver)
  - [Why did you reuse the existing `config.json`?](#why-did-you-reuse-the-existing-configjson)
  - [Why didn't you include the debs I need](#why-didnt-you-include-the-debs-i-need)
  - [Why is my https url not working?](#why-is-my-https-url-not-working)
- [References](#references)

## Prerequisites

- A Mac
- A jailbroken iPhone
- Apple Command Line Tools (`xcode-select --install`)
- imobiledevice tools (`brew install libimobiledevice`)
- Optional but **highly recommend** creating a ssh keypair
- Setup your ssh config entry. Life is much easier when your ssh sessions are remembered.

  ```sh
  cat ~/.ssh/config
  Host iphone localhost
    HostName localhost
    User root
    Port 2222
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    #IdentityFile ~/.ssh/main.pub

  Host *
    ControlMaster auto
    ControlPath /tmp/%r@%h:%p
    ControlPersist 1800
  ```

## Getting started

It is assumed you know your way around a command line. Commands are ran on your computer connected to a single iOS device.

1. Grab a valid iOS 14+ device and jailbreak it: https://ios.cfw.guide/get-started/select-iphone/
1. Clone this git repo.

   ```sh
   git clone https://github.com/clburlison/dmon
   ```

1. Change directory into the freshly cloned repo.

   ```sh
   cd dmon
   ```

1. Create a `config.json` at the root of this repo with the correct values.

   Make sure to remove all `// comments` before saving. They are not valid JSON!

   ```js
   {
     "api_key": "YOUR_API_KEY",
     "device_configuration_manager_url": "https://YOUR_AWESOME_DCM_URL",
     "dmon_url": "https://YOUR_URL:PORT/path/", // Url to download update files from. Leave empty if you don't want to use the update function.
     "dmon_username": "username", // Basic Auth username. Leave empty if not used
     "dmon_password": "password" // Basic Auth password. Leave empty if not used
   }
   ```

1. Download any extra .deb files you want installed into the `./debs/` directory.

   debs to include:

   - https://apt.bingner.com/debs/1443.00/com.ex.substitute_2.3.1_iphoneos-arm.deb
   - https://apt.bingner.com/debs/1443.00/com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb
   - https://repo.spooferpro.com/debs/com.spooferpro.kernbypass_1.1.0_iphoneos-arm64.deb
   - https://github.com/clburlison/dmon/releases
   - (Optional - Required for pogo.ipa updates) https://cydia.akemi.ai/debs/nodelete-ai.akemi.appsyncunified.deb
   - (Optional - Required for pogo.ipa updates) https://cydia.akemi.ai/debs/nodelete-ai.akemi.appinst.deb
   - **Potentially any paid/private debs. Nudge, nudge, wink, wink**

1. Grab a copy of Pokemon Go via [majd/ipatool](https://github.com/majd/ipatool).

   ```sh
   brew tap majd/repo
   brew install ipatool
   ipatool auth login -e 'youremail@example.com' -p 'PASSWORD'
   ipatool download --purchase -b com.nianticlabs.pokemongo -o pogo.ipa
   ```

1. Connect your iOS device to your computer via USB.
1. Open Terminal.app and run (remember only to have one phone connected).

   ```sh
   # Alteratively you can pass -u <device-uuid> if multiple phones are connected
   iproxy 2222 22
   ```

1. Then, in a separate terminal window, run:

   ```sh
   ssh root@localhost -p 2222 # default password is 'alpine'
   # Now disconnect with: Control + d
   ```

1. Now run:

   ```sh
   ./bin/setup
   # If you want to setup passwordless ssh then pass the argument with the path to your public key
   ./bin/setup -s ~/.ssh/main.pub
   ```

1. Assuming everything worked correctly, your phone is now properly configured.

Bonus items that are out of scope for this project.

- Configure your device as supervised and push a wireless mobileconfig profile
- Configure your device to use Shared Internet from your Mac
- Supervise your device and push a global proxy to route requests through HAproxy

## Testing

- All testing has been completed with iOS 15 using palera1n
- Only confirmed on older A9 processors, aka iPhone SE first gen
- DEB Package is built on macOS Ventura

## Commonly asked questions

### Why didn't you use Theos to build the deb?

I was expecting to add a few external compiled binaries and wanted to avoid reading the documentation. But, unfortunately, things changed, and I don't want to rewrite it.

### How can I stop it?!?!

1. Close Pokemon Go on the phone
2. ssh into the phone & unload the launch daemon

   ```sh
   ssh iphone
   /usr/bin/launchctl unload /Library/LaunchDaemons/com.github.clburlison.dmon.plist
   ```

### How do I set up the webserver?

It is a flat structure. You can use Nginx, Apache, Caddy, Python, NodeJS, etc. Your files should be named:

```sh
top_level_folder
├── gc.deb
├── pogo.ipa
└── version.txt
```

Your `version.txt` file should have the following text. Update the versions to match what is currently released.

```sh
gc: 2.0.248
pogo: 0.265.0
```

Then in your config, point `dmon_url` to `http://HOSTNAME:PORT/top_level_folder`.

### Why did you reuse the existing `config.json`?

I was lazy and figured this would make it easier for you. Now bugger off.

### Why didn't you include the debs I need?

I don't have the original author's permission to upload their files.

### Why is my https url not working?

dmon is using the stock CA Certificates installed as part of the iOS jailbreak. The Procursus Team placed files in `/usr/lib/ssl/cacert.pem` and I figured it would be safe to keep using them. Those root certs might have expired and need an update if you are running into an issue.

## References

- [dm.pl](https://github.com/theos/dm.pl)
- [theos](https://theos.dev)
- [appknox/Open](https://github.com/appknox/Open) which was originally from [conradev/Open](https://github.com/conradev/Open)
