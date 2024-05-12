#!/bin/bash

echo "[DEBUG]################### SETUP STEP ###################"
mkdir -p {/tmp/archiso_custom/archiso_custom,/tmp/archiso_custom/archiso_tmp,/tmp/archiso_custom/out}
git clone https://gitlab.archlinux.org/archlinux/archiso.git /tmp/archiso_custom/archiso

echo "[DEBUG]################### ADD JQ PACKAGE ###################"
echo "jq" >> /tmp/archiso_custom/archiso/configs/releng/packages.x86_64

echo "[DEBUG]################### ADD FAST AUTO INSTALL SCRIPT ###################"
cp /al_compact_installer.sh /tmp/archiso_custom/archiso/configs/releng/airootfs/root/.al_compact_installer.sh

echo "[DEBUG]################### ADD FAST AUTO INSTALL CONFIG JSON ###################"
cp /config.json /tmp/archiso_custom/archiso/configs/releng/airootfs/root/config.json

echo "[DEBUG]################### ADD FAST AUTO INSTALL SCRIPT TO STARTUP ###################"
echo "chmod +x ~/.al_compact_installer.sh || true" >> /tmp/archiso_custom/archiso/configs/releng/airootfs/root/.zlogin
echo "~/.al_compact_installer.sh | tee auto_install.log" >> /tmp/archiso_custom/archiso/configs/releng/airootfs/root/.zlogin

cp -r /tmp/archiso_custom/archiso/configs/releng /tmp/archiso_custom/archiso/archiso/mkarchiso /tmp/archiso_custom/archiso_custom/
rm -rf /tmp/archiso_custom/archiso

echo "[DEBUG]################### CHECK BEFORE BUILD ###################"
arch-install-scripts awk dosfstools e2fsprogs erofs-utils findutils grub gzip libarchive libisoburn mtools openssl pacman sed squashfs-tools

echo "[DEBUG]################### BUILD ISO ###################"
/tmp/archiso_custom/archiso_custom/mkarchiso -v -w /tmp/archiso_custom/archiso_tmp -o /tmp/archiso_custom/out /tmp/archiso_custom/archiso_custom/releng/

echo "============================================="
echo "END archiso has been build"
echo "Bien Jouer Soldat !!!"
echo "============================================="