#!/bin/sh

## Q: How to create a package cache?
## A: Run following command after reboot the newly installed system:
##    $ tar -zcf pacman.tar.gz -C / var/cache/pacman/


## START DEFAULT CONF
SWAP_SIZE='4G'

MIRROR='http://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch'
PKG_CACHE="pacman.tar.gz"

HOSTNAME=""
USERNAME="zyguan"
HOST_PREFIX="server"
## END DEFAULT CONF


## START LOAD CONFIG
CONF="$(pwd)/archstrap.conf"
if [ -f "$CONF" ]; then
    source "$CONF"
fi
## END LOAD CONFIG


## START FORMAT COMMAND
if [ "$1" = "format" ]; then
    echo "o
n



+$SWAP_SIZE
n




w
"|fdisk /dev/sda

    mkswap /dev/sda1
    swapon /dev/sda1
    mkfs.ext4 -F /dev/sda2
    mount /dev/sda2 /mnt

    exit 0
fi
## END FORMAT COMMAND


## START INSTALL COMMAND
if [ "$1" = "install" ]; then
    # extract package cache if exists
    if [ -f "$PKG_CACHE" ]; then
        mkdir -p /mnt/var/cache
        tar -xf "$PKG_CACHE" -C /mnt
    fi

    # run pacstrap
    echo "Server = $MIRROR" > /etc/pacman.d/mirrorlist
    pacstrap /mnt --needed base base-devel grub sudo openssh vim bash-completion

    # set fstab
    cat <<EOF > /mnt/etc/fstab
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
EOF
    genfstab -p /mnt >> /mnt/etc/fstab

    # set hostname
    if [ "$HOSTNAME" = "" ]; then
        HOSTNAME="$HOST_PREFIX-$(ip link|grep ether|md5sum|cut -b -6)"
    fi
    echo "$HOSTNAME" > /mnt/etc/hostname

    # set locale
    arch-chroot /mnt ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    arch-chroot /mnt sed -ri 's/^#((en_US|zh_CN)\.UTF-8 UTF-8)/\1/' /etc/locale.gen
    arch-chroot /mnt echo LANG=en_US.UTF-8 > /etc/locale.conf
    arch-chroot /mnt locale-gen

    # enable common services
    arch-chroot /mnt systemctl enable dhcpcd.service
    arch-chroot /mnt systemctl enable sshd.service
    arch-chroot /mnt systemctl enable systemd-timesyncd.service

    # install grub
    arch-chroot /mnt grub-install /dev/sda
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    # run mkinitcpio
    arch-chroot /mnt mkinitcpio -p linux

    # setup default user
    arch-chroot /mnt useradd -m -U -G wheel -s /bin/bash "$USERNAME"
    echo "Set password for root"
    arch-chroot /mnt passwd
    echo "Set password for $USERNAME"
    arch-chroot /mnt passwd "$USERNAME"

    read -p "Edit sudoer? [Y/n] " VISUDO
    if [ "$VISUDO" = "y" -o "$VISUDO" = "" ]; then
        arch-chroot /mnt visudo
    fi

    exit 0
fi
## END INSTALL COMMAND


## START INFO COMMAND
if [ "$1" = "info" ]; then
    if [ "$HOSTNAME" = "" ]; then
        HOSTNAME="$HOST_PREFIX-$(ip link|grep ether|md5sum|cut -b -6)"
    fi
    cat<<EOF
SWAP_SIZE: $SWAP_SIZE
PKG_CACHE: $PKG_CACHE
MIRROR:    $MIRROR
HOSTNAME:  $HOSTNAME
USERNAME:  $USERNAME
EOF
    exit 0
fi
## END INFO COMMAND


cat <<EOF
usage: archstrap.sh command

available comands:
  format     partition the disk
  install    install arch linux
  info       show config info
                 
EOF
exit 1
