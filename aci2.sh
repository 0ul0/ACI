#!/bin/bash
echo "Скрипт установки Arch Linux с bspwm"
# Задайте свои переменные
DISK="" # Пример: /dev/sda
HOSTNAME="myarch"
USERNAME="user"
PASSWORD="password"
TIMEZONE="Europe/Moscow"
LOCALE="en_US.UTF-8"
KEYMAP="us"
LANG="en_US.UTF-8"
# Функции установки
partition_disk() {
    echo "Разбивка диска и форматирование"
    # Предполагается, что диск уже выбран и хранится в переменной $DISK
    # Здесь показан пример разбиения диска для UEFI системы
    # /dev/sdX1 - EFI раздел
    # /dev/sdX2 - Корневой раздел
    # /dev/sdX3 - Домашний раздел
    # Память подкачки (swap) не создается для упрощения скрипта
    # Пожалуйста, настройте разбиение диска в соответствии с вашими требованиями
    parted -s "$DISK" mklabel gpt \
        mkpart ESP fat32 1MiB 513MiB \
        mkpart root ext4 513MiB 100% \
        set 1 esp on
}
format_partitions() {
    echo "Форматирование разделов"
    mkfs.fat -F32 ${DISK}1
    mkfs.ext4 ${DISK}2
}
mount_partitions() {
    echo "Монтирование разделов"
    mount ${DISK}2 /mnt
    mkdir /mnt/boot
    mount ${DISK}1 /mnt/boot
}
install_base_system() {
    echo "Установка базовой системы"
    pacstrap /mnt base base-devel linux linux-firmware vim intel-ucode # или amd-ucode для AMD
}
configure_system() {
    echo "Настройка системы"
    # Fstab
    genfstab -U /mnt >> /mnt/etc/fstab
    # Chroot
    arch-chroot /mnt /bin/bash <<EOF
    # Timezone
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    hwclock --systohc
    # Locale
    echo "${LOCALE} UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=${LANG}" > /etc/locale.conf
    echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
    # Hostname
    echo "${HOSTNAME}" > /etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain\t${HOSTNAME}" > /etc/hosts
    # Initramfs
    mkinitcpio -P
    # Root password
    echo "root:${PASSWORD}" | chpasswd
    # User setup
    useradd -m -G wheel -s /bin/bash ${USERNAME}
    echo "${USERNAME}:${PASSWORD}" | chpasswd
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers.d/wheel
    # Bootloader
    bootctl install
    echo "default arch" > /boot/loader/loader.conf
    echo -e "title   Arch Linux\nlinux   /vmlinuz-linux\ninitrd  /intel-ucode.img\ninitrd  /initramfs-linux.img\noptions root=PARTUUID=$(blkid -s PARTUUID -o value ${DISK}2) rw" > /boot/loader/entries/arch.conf # Замените intel-ucode на amd-ucode, если у вас процессор AMD
    # NetworkManager
    pacman -S --noconfirm networkmanager
    systemctl enable NetworkManager
    # bspwm and sxhkd
    pacman -S --noconfirm bspwm sxhkd
    mkdir -p /home/${USERNAME}/.config/{bspwm,sxhkd}
    cp /usr/share/doc/bspwm/examples/bspwmrc /home/${USERNAME}/.config/bspwm/
    cp /usr/share/doc/bspwm/examples/sxhkdrc /home/${USERNAME}/.config/sxhkd/
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/
    chmod +x /home/${USERNAME}/.config/bspwm/bspwmrc
    # Xorg
    pacman -S --noconfirm xorg-server xorg-xinit xorg-apps xterm
    # Установка минимального окружения, чтобы можно было запустить bspwm
    echo "exec bspwm" > /home/${USERNAME}/.xinitrc
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.xinitrc
    # Завершаем настройку
    exit
EOF
}
# Запуск функций
read -p "Введите имя диска (например, /dev/sda): " DISK
partition_disk
format_partitions
mount_partitions
install_base_system
configure_system
# Перезагрузка
echo "Установка завершена. Пожалуйста, перезагрузите систему."
