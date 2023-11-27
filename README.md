# Arch auto install scripts

[![Made with Bash](https://img.shields.io/badge/Made%20with-Bash-1f825f.svg)](./)

## Description

Arch Linux tools going from building iso to installing a minimalist Arch Linux

Currently available:

- auto install script to do the "fatest" arch linux install "you ever seen"

- setup to build custom arch linux iso with the auto install script in it

## Auto Install Script

after booting on any archlinux iso run

```
curl -o fast_install.sh https://raw.githubusercontent.com/K-A-R-I-M/archautoinstallscript/main/arch_linux_installer.sh; chmod +x ./fast_install.sh; ./fast_install.sh
```

## Build ISO setup

### Install Podman

Follow the instructions (according to your OS) in the link below

[Podman Installation](https://podman.io/docs/installation)

### Clone and Run

after installing Podman on your machine run

For Windows and Linux

```
git clone https://github.com/K-A-R-I-M/archautoinstallscript.git
cd archautoinstallscript
make
# or (if make fails)
# sudo make (on Linux)
```

## Support

[K-A-R-I-M](https://github.com/K-A-R-I-M)

## Authors and acknowledgment

[K-A-R-I-M](https://github.com/K-A-R-I-M)
