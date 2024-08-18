#!/bin/bash
echo "[DEBUG]################### DEFAULT VARS ###################"

if [ -f "config.json" ]; then
echo "[DEBUG]################### config found !!! ###################"
echo "[DEBUG]################### load config ###################"
    uefi_boot=$(jq 'if .uefi_boot then 1 else 0 end' config.json | tr -d \")
    root_passwd=$(jq '.root_passwd' config.json | tr -d \")
    hostname=$(jq '.hostname' config.json | tr -d \")
    swapon_size=$(jq '.swapon_size' config.json | tr -d \")
    base_packages=$(jq '.base_packages' config.json | tr -d \")
    disk_name=$(jq '.disk_name' config.json | tr -d \")
    echo "########################  config"
    echo $uefi_boot
    echo $root_passwd
    echo $hostname
    echo $swapon_size
    echo $base_packages
    echo $disk_name
else
    exit 1
fi

echo "[DEBUG]################### BOOTCHECK ###################"
if [[ "0" == `ls /sys/firmware/efi/efivars &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] UEFI works"
    uefi_boot=1
else
    echo "[ERROR] UEFI not configured or available !!!"
    # exit 0
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

echo '[DEBUG] fetch disks list...'	
lsblk -ldn --output NAME SIZE

DISK=$disk_name

if [[ $DISK != "" ]];
then
    if [[ "0" == `lsblk -ldn --output NAME | grep -E "(^| )${DISK}( |$)" &> /dev/null; echo $?` ]]; then
        echo "[DEBUG] ${DISK} is an available and a valid disk"
        if [[ ${DISK} == "sd"* ]]; then
            is_sd=1
        fi
    else
        echo "[ERROR] ${DISK} is not an available or not a valid disk"
        exit 1
    fi
else 
    exit 1
fi

echo "[[!!!  WARNING  !!!]]"
echo "All your data will be removed from this disk you have 10 sec to cancel this with Ctrl + C :"
for i in {1..10};
do
    echo $i
    sleep 1
done
echo "[DEBUG] Let's go !!!!!!!!!!!!"

echo "[DEBUG]############# clean disk #############"
echo "wipefs -af /dev/$disk_name"
if [[ "0" == `wipefs -af /dev/$disk_name &> /dev/null; echo $?` ]]; then
    echo "[DEBUG] wipe succeed"
else
    echo "[ERROR] wipe failed"
    exit 1
fi
sleep 2
echo "[DEBUG]############# Basic Partition #############"
parted -s /dev/$disk_name mklabel gpt
parted -s /dev/$disk_name mkpart ESP fat32 1MB 513MB
parted -s /dev/$disk_name set 1 boot on
if [[ ${uefi_boot} == "0" ]]; then
    parted -s /dev/$disk_name set 1 bios_grub on
fi
parted -s /dev/$disk_name name 1 efi
parted -s /dev/$disk_name mkpart primary 513MB 1024MB
parted -s /dev/$disk_name name 2 boot
parted -s /dev/$disk_name mkpart primary 1024MB $swapon_size
parted -s /dev/$disk_name name 3 swap
parted -s /dev/$disk_name mkpart primary $swapon_size 100%
parted -s /dev/$disk_name name 4 root
sleep 2
echo "[DEBUG]############# Creating filesystem #############"
mkfs.vfat -F 32 /dev/${disk_name}1
mkfs.ext2 /dev/${disk_name}2
mkswap /dev/${disk_name}3
mkfs.ext4 /dev/${disk_name}4
sleep 2
echo "[DEBUG]############# Mount Partition #############"
mount /dev/${disk_name}4 /mnt
mount --mkdir /dev/${disk_name}2 /mnt/boot
mount --mkdir /dev/${disk_name}1 /mnt/boot/efi
swapon /dev/${disk_name}3
sleep 2
echo "[DEBUG]################### BASE INSTALL ###################"
pacstrap -K /mnt $base_packages

echo "[DEBUG]################### Fstab ###################"
genfstab -U /mnt >> /mnt/etc/fstab
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

echo "[DEBUG]################### NetworkManager ###################"
systemctl enable NetworkManager

echo "[DEBUG]################### SSH ###################"
systemctl enable sshd

echo "[DEBUG]################### Passwd ###################"
echo "root:${root_passwd}" | chpasswd

echo "[DEBUG]################### GRUB ###################"
if [[ ${uefi_boot} == "1" ]]; then
    echo "UEFI mode"
    mkdir /boot/efi
    grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi --recheck
else
    echo "BIOS (Legacy) mode"
    grub-install --target=i386-pc --recheck /dev/${disk_name}
fi
grub-mkconfig -o /boot/grub/grub.cfg


echo "[DEBUG]################### END ###################"
exit
EOF

echo "[DEBUG]################### Chroot Script Setup ###################"
chmod +x /mnt/startup-chroot.sh && echo $?

echo "[DEBUG]################### Chroot ###################"
result=$(arch-chroot /mnt ./startup-chroot.sh; echo $?)
if [[ "0" == $result ]]; then
    echo "[DEBUG] arch-chroot succeed"
else
    echo "[ERROR] arch-chroot failed"
    echo $result
fi

echo "#### umount"
umount -a

echo "#### reboot"

echo "############################################################"
echo "############################################################"
read -p "[[WARNING]] [[Final Reboot]] Your installation in finished! Do you want to reboot now? [y/n]: " formatdiskchoice
if [[ "$formatdiskchoice" == "y" ]];
then
    echo "[DEBUG] Let's go !!!!!!!!!!!!"
    reboot
fi

sleep 2