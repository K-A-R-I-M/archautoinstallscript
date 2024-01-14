# Arch auto install scripts

[![Shell Script](https://img.shields.io/badge/bash-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)](./)[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](./)[![Arch](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff&style=for-the-badge)](./)

## Description

Arch Linux tools going from building an Arch Linux iso using archiso to installing a minimalist Arch Linux

Currently available:

- auto install script to do the "fatest" arch linux install "you ever seen"

- setup to build custom arch linux iso with the auto install script in it

## Auto Install Script

Requierment :

```
any archlinux iso
```

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
