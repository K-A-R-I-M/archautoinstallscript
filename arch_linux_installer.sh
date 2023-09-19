#!/bin/bash
echo "[DEBUG]################### VARS ###################"
uefi_boot=0
root_passwd="root"
hostname="arch"

echo "[DEBUG]################### BOOTCHECK ###################"
if [[ "0" == `ls /sys/firmware/efi/efivars &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] UEFI works"
    uefi_boot=1
else
    echo "[ERROR] UEFI not configured or available !!!"
    exit 0
fi

echo "[DEBUG]################### NETWORK ###################"
if [[ "0" == `ip link | grep "state UP" &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] Connection UP"
else
    echo "[ERROR] No Connection"
    exit 0
fi

if [[ "0" == `ping -c 1 archlinux.org &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] test ping archlinux.org succeed"
else
    echo "[ERROR] test ping archlinux.org failed"
    exit 0
fi
echo "[DEBUG]################### TIME ###################"
echo "[DEBUG] Set time"
timedatectl set-ntp true

echo "[DEBUG]################### DISK PATITION ###################"

echo "[DEBUG] list of disks available : "
lsblk -l | awk '/disk/ {print "----  "$1}'

# chosendisk="USER INPUT"
read -p "Selected Disk: " chosendisk

is_sd=0

if [[ "0" == `lsblk -ldn --output NAME | grep -E "(^| )${chosendisk}( |$)" &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] ${chosendisk} is an available and a valid disk"
    if [[ ${chosendisk} == "sd"* ]]; then
        is_sd=1
    fi
else
    echo "[ERROR] ${chosendisk} is not an available or not a valid disk"
    exit 1
fi

read -p "[[!!!!!!!!WARNING!!!!!!!!]] Do you want to remove all your data from this disk [y/n]: " formatdiskchoice
if [[ "$formatdiskchoice" == "y" ]]; then
    echo "[DEBUG] Let's go !!!!!!!!!!!!"
else
    echo "[END] Not destroying your data"
    exit 1
fi

echo "[DEBUG]############# clean disk #############"
echo "wipefs -af /dev/$chosendisk"
if [[ "0" == `wipefs -af /dev/$chosendisk &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] wipe succeed"
else
    echo "[ERROR] wipe failed"
    exit 1
fi
sleep 2
echo "[DEBUG]############# Basic Partition #############"
parted -s /dev/$chosendisk mklabel gpt
parted -s /dev/$chosendisk mkpart ESP fat32 1MB 513MB
parted -s /dev/$chosendisk set 1 boot on
if [[ ${uefi_boot} == "0" ]]; then
    parted -s /dev/$chosendisk set 1 bios_grub on
fi
parted -s /dev/$chosendisk name 1 efi
parted -s /dev/$chosendisk mkpart primary 513MB 1024MB
parted -s /dev/$chosendisk name 2 boot
parted -s /dev/$chosendisk mkpart primary 1024MB 16384MB
parted -s /dev/$chosendisk name 3 swap
parted -s /dev/$chosendisk mkpart primary 16384MB 100%
parted -s /dev/$chosendisk name 4 root
sleep 2
echo "[DEBUG]############# Creating filesystem #############"
mkfs.vfat -F 32 /dev/${chosendisk}1
mkfs.ext2 /dev/${chosendisk}2
mkswap /dev/${chosendisk}3
mkfs.ext4 /dev/${chosendisk}4
sleep 2
echo "[DEBUG]############# Mount Partition #############"
mount /dev/${chosendisk}4 /mnt
mount --mkdir /dev/${chosendisk}2 /mnt/boot
mount --mkdir /dev/${chosendisk}1 /mnt/boot/efi
swapon /dev/${chosendisk}3
sleep 2
echo "[DEBUG]################### BASE INSTALL ###################"
pacstrap -K /mnt base linux linux-firmware grub efibootmgr vim bash-completion openssh dhclient ansible networkmanager

echo "[DEBUG]################### Fstab ###################"
genfstab -U /mnt >> /mnt/etc/fstab


echo "[DEBUG]################### NetworkD ###################"
ln -s /usr/lib/systemd/system/systemd-networkd.service /mnt/etc/systemd/system/multi-user.target.wants/
sleep 2

cat << EOF >> /mnt/startup-chroot.sh

echo "[DEBUG]################### Time zone ###################"
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

echo "[DEBUG]################### Localization ###################"
sed -i 's/^#en_US.UTF-8.*/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo "[DEBUG]################### Network ###################"
echo $hostname > /etc/hostname

echo "[DEBUG]################### Passwd ###################"
echo "root:${root_passwd}" | chpasswd

echo "[DEBUG]################### GRUB ###################"
if [[ ${uefi_boot} == "1" ]]; then
    echo "UEFI mode"
    mkdir /boot/efi
    grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi --recheck
else
    echo "BIOS (Legacy) mode"
    grub-install --target=i386-pc --recheck /dev/${chosendisk}
fi
grub-mkconfig -o /boot/grub/grub.cfg


echo "[DEBUG]################### END ###################"
exit
EOF

echo "[DEBUG]################### Chroot Script Setup ###################"
chmod +x /mnt/startup-chroot.sh && echo $?

echo "[DEBUG]################### Chroot ###################"
if [[ "0" == `arch-chroot /mnt ./startup-chroot.sh; echo $?` ]]; then
    echo "[DEBUG] arch-chroot succeed"
else
    echo "[ERROR] arch-chroot failed"
    exit 0
fi
echo "#### umount"
#umount -a
echo "#### reboot"
#reboot
sleep 2
