#!/bin/bash
echo "[DEBUG]################### DEFAULT VARS ###################"
uefi_boot=0
root_passwd="root"
hostname="arch"
swapon_size=2048MB
base_packages="base linux linux-firmware grub efibootmgr vim bash-completion openssh dhclient networkmanager dolphin alacritty sddm"
# swapon_size=16384MB

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
IFS=$'\n' disks=( $(lsblk -ldn --output NAME) )

choices_disks=();
for key in "${!disks[@]}";
do
	choices_disks+=("${disks[$key]}" "");
done;

choices_disks+=("check disks info" "")
DISK=""

_info_lsblk(){
    lsblk > disks_display
    whiptail --textbox disks_display 16 78 10
    DISK=$(whiptail --title "Disks List" --menu "Choose a disk" 16 78 10 "${choices_disks[@]}" 3>&1 1>&2 2>&3)
    is_sd=0
    chosendisk=${DISK}
}

while true;
do
    _info_lsblk
    if [[ $DISK != "" ]] && [[ $DISK != "check disks info" ]];
    then
        break
    fi
done


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
parted -s /dev/$chosendisk mkpart primary 1024MB $swapon_size
parted -s /dev/$chosendisk name 3 swap
parted -s /dev/$chosendisk mkpart primary $swapon_size 100%
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
    grub-install --target=i386-pc --recheck /dev/${chosendisk}
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
