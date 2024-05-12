FROM docker.io/library/archlinux as builder

COPY ./*.sh /

COPY ./config.json /

RUN chmod +x /*.sh

RUN pacman -Suy --noconfirm

RUN pacman -S --noconfirm git awk dosfstools\
    e2fsprogs erofs-utils findutils grub\
    gzip libarchive libisoburn mtools\
    openssl pacman sed squashfs-tools\
    arch-install-scripts

FROM builder

CMD /pull_modify_iso.sh