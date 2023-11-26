FROM docker.io/library/archlinux as builder

COPY ./*.sh /

RUN chmod +x /pull_modify_iso.sh

RUN chmod +x /arch_linux_installer.sh

RUN pacman -Suy --noconfirm

RUN pacman -S --noconfirm git awk dosfstools\
    e2fsprogs erofs-utils findutils grub\
    gzip libarchive libisoburn mtools\
    openssl pacman sed squashfs-tools\
    arch-install-scripts

FROM builder

CMD /pull_modify_iso.sh