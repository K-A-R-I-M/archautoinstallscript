#!/bin/bash

echo "[DEBUG]################### BOOTCHECK ###################"
if [[ "0" == `ls /sys/firmware/efi/efivars &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] UEFI works"
else
    echo "[ERROR] UEFI not configured or available !!!"
    exit 1
fi

echo "[DEBUG]################### NETWORK ###################"
if [[ "0" == `ip link | grep "state UP" &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] Connection UP"
else
    echo "[ERROR] No Connection"
    exit 1
fi

if [[ "0" == `ping -c 1 archlinux.org &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] test ping archlinux.org succeed"
else
    echo "[ERROR] test ping archlinux.org failed"
    exit 1
fi
echo "[DEBUG]################### TIME ###################"
echo "[DEBUG] Set time"
timedatectl set-ntp true
echo "[DEBUG] Check time"
timedatectl status

echo "[DEBUG]################### DISK PATITION ###################"

echo "[DEBUG] list of disks available : "
lsblk -l | awk '/disk/ {print "----  "$1}'

# chosendisk="USER INPUT"
read -p "Selected Disk: " chosendisk

if [[ "0" == `lsblk -ldn --output NAME | grep -E "(^| )${chosendisk}( |$)" &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] ${chosendisk} is an available and a valid disk"
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

echo "[DEBUG]############# DISK BASIC Partition #############"
parted -s /dev/$chosendisk mklabel gpt
parted -s /dev/$chosendisk mkpart ESP fat32 1MiB 513MiB
parted -s /dev/$chosendisk set 1 boot on
parted -s /dev/$chosendisk name 1 efi
parted -s /dev/$chosendisk mkpart primary 513MiB 800MiB
parted -s /dev/$chosendisk name 2 boot
parted -s /dev/$chosendisk mkpart primary 800MiB 100%
parted -s /dev/$chosendisk name 3 lvm-partition
parted -s /dev/$chosendisk set 3 lvm on
parted -s /dev/$chosendisk print
parted -s /dev/$chosendisk quit

echo "[DEBUG]############# LVM Partition #############"
pvcreate /dev/${chosendisk}
pvs
vgcreate mainvg /dev/${chosendisk}3
vgs
lvcreate -L 16G mainvg -n swap
lvcreate -l 100%FREE mainvg -n root
lvs

echo "[DEBUG]############# Creating filesystem #############"
mkfs.vfat -F 32 /dev/sdX1
mkfs.ext2 /dev/sdX2
mkswap /dev/mainvg/swap
mkfs.ext4 /dev/mainvg/root

echo "[DEBUG]############# LVM Partition #############"
mount /dev/mainvg/root /mnt
mount --mkdir /dev/sdX2 /mnt/boot
mount --mkdir /dev/sdX1 /mnt/boot/efi
swapon /dev/mainvg/swap


echo "[DEBUG]################### BASE INSTALL ###################"
pacstrap /mnt base linux linux-firmware ansible grub efibootmgr

echo "[DEBUG]################### Fstab ###################"
genfstab -U /mnt >> /mnt/etc/fstab


echo "[DEBUG]################### NetworkD ###################"
ln -s /usr/lib/systemd/system/systemd-networkd.service /mnt/etc/systemd/system/multi-user.target.wants/

echo "[DEBUG]################### Network ###################"
read -p "Selected a hostname: " chosenhostname

cat << EOF >> /mnt/startup-chroot.sh

echo "[DEBUG]################### Time zone ###################"
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

echo "[DEBUG]################### Localization ###################"
sed -i 's/^#en_US.UTF-8.*/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo "[DEBUG]################### Network ###################"
echo $chosenhostname > /etc/hostname

echo "[DEBUG]################### Passwd ###################"
passwd

echo "[DEBUG]################### GRUB ###################"
mkdir /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --recheck
grub-mkconfig -o /boot/grub/grub.cfg
grub-mkconfig -o  /boot/efi/EFI/arch/grub.cfg

echo "[DEBUG]################### END ###################"
exit
EOF

echo "[DEBUG]################### Chroot Script Setup ###################"
chmod +x /mnt/startup-chroot.sh

echo "[DEBUG]################### Chroot ###################"
arch-chroot /mnt ./startup-chroot.sh

echo "#### umount"
umount -a
echo "#### reboot"
reboot
