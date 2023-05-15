#!/bin/bash

echo "[DEBUG]################### BOOTCHECK ###################"
if [[ "0" == `ls /sys/firmware/efi/efivars &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] UEFI works"
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

diskslist=$(lsblk -rdo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}')
chosendisk=(dialog --menu "Select a disk:" 0 0 0 $diskslist 2>&1)


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

echo "[DEBUG]############# LVM Partition #############"
pvcreate /dev/$chosendisk
pvs
vgcreate mainvg /dev/$chosendisk
vgs
lvcreate -L 8G mainvg -n boot
lvcreate -L 16G mainvg -n swap
lvcreate -l 100%FREE mainvg -n root
lvs

echo "[DEBUG]############# Creating filesystem #############"
mkfs.vfat -F 32 /dev/mainvg/boot
mkswap /dev/mainvg/swap
mkfs.ext4 /dev/mainvg/root

echo "[DEBUG]############# LVM Partition #############"
mount /dev/mainvg/root /mnt
mount --mkdir /dev/mainvg/boot /mnt/boot
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
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo "[DEBUG]################### END ###################"
exit
EOF

echo "[DEBUG]################### Chroot Script Setup ###################"
chmod +x /mnt/startup-chroot.sh

echo "[DEBUG]################### Chroot ###################"
if [[ "0" == `arch-chroot /mnt ./startup-chroot.sh &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] arch-chroot succeed"
else
    echo "[ERROR] arch-chroot failed"
    exit 0
fi
echo "#### umount"
#umount -a
echo "#### reboot"
#reboot
