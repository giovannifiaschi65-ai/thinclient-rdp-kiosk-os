#!/bin/bash
# ==============================================================================
# Script di compilazione immagine ISO ibrida (Legacy BIOS + UEFI x86_64/ia32)
# Sistema Operativo Thin Client / Kiosk RDP (base Debian 12 Bookworm amd64)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

WORK_DIR="${PROJECT_ROOT}/work"
CHROOT_DIR="${WORK_DIR}/chroot"
ISO_DIR="${WORK_DIR}/iso_root"
OUTPUT_DIR="${PROJECT_ROOT}/output"
ISO_NAME="${ISO_NAME:-thinclient-rdp-kiosk-amd64.iso}"
ISO_PATH="${OUTPUT_DIR}/${ISO_NAME}"

DEBIAN_RELEASE="bookworm"
DEBIAN_MIRROR="http://deb.debian.org/debian"

if [ "$(id -u)" -ne 0 ]; then
    echo "Errore: eseguire questo script con privilegi di root (sudo)."
    exit 1
fi

cleanup_mounts() {
    local had_e=0
    case "$-" in *e*) had_e=1 ;; esac
    set +e
    for mp in \
        "${CHROOT_DIR}/run" \
        "${CHROOT_DIR}/sys" \
        "${CHROOT_DIR}/proc" \
        "${CHROOT_DIR}/dev/pts" \
        "${CHROOT_DIR}/dev"; do
        if mountpoint -q "$mp" 2>/dev/null; then
            umount -lf "$mp" 2>/dev/null || true
        fi
    done
    [ "$had_e" -eq 1 ] && set -e || true
}
trap cleanup_mounts EXIT

echo "==> [1/8] Pulizia ambiente di lavoro e normalizzazione file..."
cleanup_mounts
rm -rf "${WORK_DIR}" "${OUTPUT_DIR}"
mkdir -p "${CHROOT_DIR}" "${ISO_DIR}/live" "${ISO_DIR}/boot/grub" "${OUTPUT_DIR}"

# Normalizza eventuali fine-riga CRLF provenienti da ambienti Windows
find "${PROJECT_ROOT}/overlay" "${PROJECT_ROOT}/build" -type f -exec sed -i 's/\r$//' {} +

echo "==> [2/8] Bootstrap sistema base Debian 12 (${DEBIAN_RELEASE} amd64)..."
KEYRING_OPT=""
if [ -f /usr/share/keyrings/debian-archive-keyring.gpg ]; then
    KEYRING_OPT="--keyring=/usr/share/keyrings/debian-archive-keyring.gpg"
fi

debootstrap \
    --arch=amd64 \
    ${KEYRING_OPT} \
    "${DEBIAN_RELEASE}" \
    "${CHROOT_DIR}" \
    "${DEBIAN_MIRROR}"

echo "==> [3/8] Preparazione mount virtuali e repository APT nel chroot..."
mount --bind /dev "${CHROOT_DIR}/dev"
mount -t devpts devpts "${CHROOT_DIR}/dev/pts"
mount -t proc proc "${CHROOT_DIR}/proc"
mount -t sysfs sysfs "${CHROOT_DIR}/sys"
mount -t tmpfs tmpfs "${CHROOT_DIR}/run"

rm -f "${CHROOT_DIR}/etc/resolv.conf"
cp -L /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf"

cat > "${CHROOT_DIR}/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian ${DEBIAN_RELEASE} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security ${DEBIAN_RELEASE}-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${DEBIAN_RELEASE}-updates main contrib non-free non-free-firmware
EOF

# Impedisce l'avvio di demoni durante l'installazione dei pacchetti nel chroot
cat > "${CHROOT_DIR}/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
chmod 0755 "${CHROOT_DIR}/usr/sbin/policy-rc.d"

# Preconfigurazione hostname, fuso orario e tastiera italiana prima di apt-get
echo "rdp-thinclient" > "${CHROOT_DIR}/etc/hostname"
cat > "${CHROOT_DIR}/etc/hosts" <<'EOF'
127.0.0.1   localhost
127.0.1.1   rdp-thinclient
::1         localhost ip6-localhost ip6-loopback
EOF

cat > "${CHROOT_DIR}/etc/default/keyboard" <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="it"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

echo "Europe/Rome" > "${CHROOT_DIR}/etc/timezone"
ln -sf /usr/share/zoneinfo/Europe/Rome "${CHROOT_DIR}/etc/localtime"
echo "a4" > "${CHROOT_DIR}/etc/papersize"

echo "==> [4/8] Installazione Kernel, Firmware, X11, GTK3, FreeRDP, USB/CUPS/SmartCard..."
chroot "${CHROOT_DIR}" /bin/bash -eux <<'CHROOT_PKG'
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C

apt-get update

apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    live-boot \
    live-boot-initramfs-tools \
    initramfs-tools \
    systemd \
    systemd-sysv \
    systemd-timesyncd \
    libpam-systemd \
    dbus \
    dbus-user-session \
    dbus-x11 \
    udev \
    kmod \
    intel-microcode \
    amd64-microcode \
    firmware-linux-free \
    firmware-misc-nonfree \
    firmware-realtek \
    firmware-amd-graphics \
    network-manager \
    iproute2 \
    iputils-ping \
    isc-dhcp-client \
    ca-certificates \
    openssl \
    locales \
    kbd \
    console-setup \
    console-data \
    xserver-xorg-core \
    xserver-xorg \
    xserver-xorg-legacy \
    xserver-xorg-input-libinput \
    xserver-xorg-video-vesa \
    xserver-xorg-video-fbdev \
    xserver-xorg-video-vmware \
    libgbm1 \
    x11-xserver-utils \
    x11-xkb-utils \
    xkb-data \
    xinit \
    xauth \
    openbox \
    plymouth \
    plymouth-themes \
    python3 \
    python3-cairo \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-3.0 \
    libgtk-3-0 \
    libgtk-3-bin \
    librsvg2-common \
    adwaita-icon-theme \
    fonts-cantarell \
    fonts-dejavu-core \
    fonts-liberation2 \
    freerdp2-x11 \
    pulseaudio \
    libpulse0 \
    alsa-utils \
    exfatprogs \
    ntfs-3g \
    cups \
    cups-client \
    cups-bsd \
    cups-filters \
    cups-browsed \
    ipp-usb \
    avahi-daemon \
    ghostscript \
    libpaper1 \
    libpaper-utils \
    printer-driver-gutenprint \
    printer-driver-hpcups \
    printer-driver-postscript-hp \
    printer-driver-brlaser \
    printer-driver-splix \
    foomatic-db-compressed-ppds \
    openprinting-ppds \
    polkitd \
    pcscd \
    libpcsclite1 \
    libccid \
    sudo \
    util-linux \
    procps \
    psmisc \
    pciutils \
    usbutils \
    parted \
    gdisk \
    dosfstools \
    e2fsprogs \
    rsync \
    grub-common \
    grub2-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    efibootmgr \
    dialog

# Configura lingua e localizzazione italiana
sed -i 's/^# *\(it_IT.UTF-8 UTF-8\)/\1/' /etc/locale.gen
grep -q '^it_IT.UTF-8 UTF-8' /etc/locale.gen || echo 'it_IT.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
update-locale LANG=it_IT.UTF-8 LC_ALL=it_IT.UTF-8

# Configura console italiana
cat > /etc/vconsole.conf <<'EOF'
KEYMAP=it
FONT=Lat15-TerminusBold16
EOF
setupcon --save-only || true

apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT_PKG

echo "==> [5/8] Copia file overlay Kiosk e configurazione sicurezza/rete..."
cp -a "${PROJECT_ROOT}/overlay/." "${CHROOT_DIR}/"

# Permessi rigorosi per eseguibili e sudoers
mkdir -p "${CHROOT_DIR}/var/lib/rdp-kiosk" "${CHROOT_DIR}/media"
chmod 0755 \
    "${CHROOT_DIR}/usr/local/bin/kiosk-tty-launcher" \
    "${CHROOT_DIR}/usr/local/bin/kiosk-xsession" \
    "${CHROOT_DIR}/usr/local/bin/rdp-kiosk-ui" \
    "${CHROOT_DIR}/usr/local/sbin/rdp-power-action" \
    "${CHROOT_DIR}/usr/local/sbin/rdp-install-disk" \
    "${CHROOT_DIR}/usr/local/sbin/rdp-save-target" \
    "${CHROOT_DIR}/usr/local/sbin/rdp-load-config" \
    "${CHROOT_DIR}/usr/local/sbin/kiosk-usb-mount" \
    "${CHROOT_DIR}/usr/local/sbin/kiosk-printer-autoconfig"
chmod 0440 "${CHROOT_DIR}/etc/sudoers.d/kiosk-power"
chown root:root "${CHROOT_DIR}/etc/sudoers.d/kiosk-power"

# Configura cups-browsed per creare automaticamente code solo per stampanti USB locali (ipp-usb)
if [ -f "${CHROOT_DIR}/etc/cups/cups-browsed.conf" ]; then
    sed -i 's/^#*BrowseRemoteProtocols.*/BrowseRemoteProtocols none/' "${CHROOT_DIR}/etc/cups/cups-browsed.conf"
    sed -i 's/^#*CreateIPPPrinterQueues.*/CreateIPPPrinterQueues LocalOnly/' "${CHROOT_DIR}/etc/cups/cups-browsed.conf"
    grep -q '^BrowseRemoteProtocols ' "${CHROOT_DIR}/etc/cups/cups-browsed.conf" || echo 'BrowseRemoteProtocols none' >> "${CHROOT_DIR}/etc/cups/cups-browsed.conf"
    grep -q '^CreateIPPPrinterQueues ' "${CHROOT_DIR}/etc/cups/cups-browsed.conf" || echo 'CreateIPPPrinterQueues LocalOnly' >> "${CHROOT_DIR}/etc/cups/cups-browsed.conf"
fi

# Compatibilità Xorg sia con driver moderni KMS (modesetting) sia legacy VESA/nomodeset
mkdir -p "${CHROOT_DIR}/etc/X11"
cat > "${CHROOT_DIR}/etc/X11/Xwrapper.config" <<'EOF'
allowed_users=console
needs_root_rights=auto
EOF

# Verifica sintassi script e configurazione sudoers nel chroot
chroot "${CHROOT_DIR}" /usr/sbin/visudo -cf /etc/sudoers.d/kiosk-power
chroot "${CHROOT_DIR}" /usr/bin/python3 -m py_compile /usr/local/bin/rdp-kiosk-ui
chroot "${CHROOT_DIR}" /bin/bash -n \
    /usr/local/bin/kiosk-tty-launcher \
    /usr/local/bin/kiosk-xsession \
    /usr/local/sbin/rdp-power-action \
    /usr/local/sbin/rdp-install-disk \
    /usr/local/sbin/rdp-save-target \
    /usr/local/sbin/rdp-load-config \
    /usr/local/sbin/kiosk-usb-mount \
    /usr/local/sbin/kiosk-printer-autoconfig

# Configurazione NetworkManager: DHCP automatico via MAC su tutte le schede Ethernet
mkdir -p "${CHROOT_DIR}/etc/NetworkManager/conf.d"
cat > "${CHROOT_DIR}/etc/NetworkManager/conf.d/10-kiosk-ethernet.conf" <<'EOF'
[main]
plugins=ifupdown,keyfile
dns=default
rc-manager=file

[ifupdown]
managed=true

[connection]
ipv4.dhcp-client-id=mac
EOF

mkdir -p "${CHROOT_DIR}/etc/network"
cat > "${CHROOT_DIR}/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback
EOF

# Disabilita terminali virtuali aggiuntivi per blindare il Kiosk
mkdir -p "${CHROOT_DIR}/etc/systemd/logind.conf.d"
cat > "${CHROOT_DIR}/etc/systemd/logind.conf.d/10-kiosk-vt.conf" <<'EOF'
[Login]
NAutoVTs=1
ReserveVT=1
EOF

echo "==> [6/8] Tema animato Plymouth, pulizia Livello 1, servizi systemd e initramfs..."
cp -f "${PROJECT_ROOT}/build/generate-plymouth-assets.py" "${CHROOT_DIR}/tmp/generate-plymouth-assets.py"

chroot "${CHROOT_DIR}" /bin/bash -eux <<'CHROOT_CFG'
export DEBIAN_FRONTEND=noninteractive
export XZ_OPT="-6 -T0"

# Genera il tema di avvio animato 'rdp-kiosk' e rimuove i temi campione pesanti di Debian
python3 /tmp/generate-plymouth-assets.py /usr/share/plymouth/themes/rdp-kiosk
rm -f /tmp/generate-plymouth-assets.py
for unused_theme in homeworld emerald solar spacefun moonlight glow fade-in spinner; do
    rm -rf "/usr/share/plymouth/themes/${unused_theme}"
done
plymouth-set-default-theme rdp-kiosk

# Crea utente non privilegiato 'kiosk' (inclusi gruppi audio, rete e stampa CUPS)
for grp in plugdev lp lpadmin; do
    getent group "$grp" >/dev/null 2>&1 || groupadd -r "$grp"
done
if ! id -u kiosk >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G video,render,input,audio,netdev,plugdev,lp,lpadmin kiosk
fi

# Blocca password di accesso diretto (nessun login da remoto/console manuale)
passwd -l kiosk
passwd -l root

# Avvio automatico Kiosk su tty1
cat > /home/kiosk/.bash_profile <<'EOF'
trap '' INT QUIT TSTP
if [ "$(tty)" = "/dev/tty1" ]; then
    exec /usr/local/bin/kiosk-tty-launcher
fi
EOF
cp /home/kiosk/.bash_profile /home/kiosk/.profile
chown -R kiosk:kiosk /home/kiosk

# Abilita servizi essenziali (rete, NTP, stampa CUPS, Smart Card PC/SC) e disabilita TTY secondari
systemctl enable NetworkManager.service
systemctl enable systemd-timesyncd.service
systemctl enable avahi-daemon.service
systemctl enable cups.service
systemctl enable cups-browsed.service
systemctl enable pcscd.socket
systemctl enable kiosk-printer-setup.service
systemctl enable rdp-load-config.service
systemctl set-default multi-user.target
systemctl mask getty@tty2.service getty@tty3.service getty@tty4.service getty@tty5.service getty@tty6.service

# Ottimizzazione Livello 1: rimuove solo firmware inutilizzabili su Thin Client x86_64 cablato
# (Wi-Fi/BT, acceleratori AI Data-Center senza video, switch 100GbE enterprise e SoC ARM)
for fw_root in /lib/firmware /usr/lib/firmware; do
    [ -d "$fw_root" ] || continue
    rm -rf \
        "$fw_root"/iwlwifi* \
        "$fw_root"/ath10k "$fw_root"/ath11k "$fw_root"/ath12k "$fw_root"/ath9k_htc "$fw_root"/ath6k "$fw_root"/ath3k* \
        "$fw_root"/brcm "$fw_root"/mediatek "$fw_root"/mrvl "$fw_root"/rtlwifi "$fw_root"/rtw88 "$fw_root"/rtw89 \
        "$fw_root"/ti-connectivity "$fw_root"/cypress "$fw_root"/qca "$fw_root"/libertas "$fw_root"/mwl8k "$fw_root"/rsi \
        "$fw_root"/netronome "$fw_root"/mellanox "$fw_root"/liquidio "$fw_root"/qed "$fw_root"/cxgb4 "$fw_root"/bnx2x \
        "$fw_root"/qcom "$fw_root"/meson "$fw_root"/rockchip "$fw_root"/sunxi "$fw_root"/amphion "$fw_root"/dpaa2 \
        "$fw_root"/nvidia/*/gsp \
        "$fw_root"/amdgpu/aldebaran* "$fw_root"/amdgpu/arcturus* "$fw_root"/amdgpu/vega20* \
        "$fw_root"/amdgpu/gc_9_4* "$fw_root"/amdgpu/sdma_4_4* "$fw_root"/amdgpu/vcn_4_0_3* || true
done

# Configura initramfs compresso in XZ con supporto framebuffer immediato (BIOS/UEFI/VirtualBox)
mkdir -p /etc/initramfs-tools/conf-hooks.d
echo "FRAMEBUFFER=y" > /etc/initramfs-tools/conf-hooks.d/plymouth-fb
if grep -q '^COMPRESS=' /etc/initramfs-tools/initramfs.conf; then
    sed -i 's/^COMPRESS=.*/COMPRESS=xz/' /etc/initramfs-tools/initramfs.conf
else
    echo "COMPRESS=xz" >> /etc/initramfs-tools/initramfs.conf
fi

# Moduli initramfs essenziali per grafica boot (VirtualBox/VESA/GOP) e dischi USB/NVMe/SATA/eMMC
cat >> /etc/initramfs-tools/modules <<'EOF'
simpledrm
vboxvideo
vmwgfx
virtio_gpu
bochs
overlay
squashfs
isofs
vfat
ext4
nls_cp437
nls_iso8859-1
nls_ascii
usb_storage
uas
xhci_hcd
xhci_pci
ehci_hcd
ehci_pci
ahci
sd_mod
nvme
mmc_block
sdhci
sdhci_pci
sdhci_acpi
EOF

# Rigenera initramfs con supporto live-boot e splash animato Plymouth
KVER="$(ls -1 /lib/modules | sort -V | tail -n 1)"
update-initramfs -c -k "${KVER}" || update-initramfs -u -k "${KVER}"

# Ottimizzazione Livello 1: pulizia documentazione, manpages, icone giganti e traduzioni estere
rm -rf \
    /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/info/* \
    /usr/share/groff/* \
    /usr/share/lintian/* \
    /usr/share/linda/* \
    /var/cache/apt/* \
    /var/cache/debconf/*-old \
    /var/log/*.log \
    /usr/share/icons/Adwaita/512x512 \
    /usr/share/icons/Adwaita/256x256 \
    /usr/share/icons/Adwaita/96x96 || true

if [ -d /usr/share/locale ]; then
    find /usr/share/locale -mindepth 1 -maxdepth 1 \
        ! -name 'it' ! -name 'it_*' ! -name 'en' ! -name 'en_*' ! -name 'locale.alias' \
        -exec rm -rf {} +
fi

gtk-update-icon-cache -f -q /usr/share/icons/Adwaita || true
CHROOT_CFG

# Rimuove policy-rc.d temporaneo e prepara resolv.conf / machine-id puliti per il Live boot
rm -f "${CHROOT_DIR}/usr/sbin/policy-rc.d"
rm -f "${CHROOT_DIR}/etc/resolv.conf"
touch "${CHROOT_DIR}/etc/resolv.conf"
chmod 0644 "${CHROOT_DIR}/etc/resolv.conf"

truncate -s 0 "${CHROOT_DIR}/etc/machine-id"
rm -f "${CHROOT_DIR}/var/lib/dbus/machine-id"
rm -rf "${CHROOT_DIR}/tmp/"* "${CHROOT_DIR}/var/tmp/"*

echo "==> [7/8] Estrazione Kernel/Initrd e compressione SquashFS..."
cleanup_mounts

VMLINUZ_FILE="$(ls -1 "${CHROOT_DIR}"/boot/vmlinuz-* | sort -V | tail -n 1)"
INITRD_FILE="$(ls -1 "${CHROOT_DIR}"/boot/initrd.img-* | sort -V | tail -n 1)"

cp -f "${VMLINUZ_FILE}" "${ISO_DIR}/boot/vmlinuz"
cp -f "${INITRD_FILE}" "${ISO_DIR}/boot/initrd.img"
cp -f "${PROJECT_ROOT}/build/grub.cfg" "${ISO_DIR}/boot/grub/grub.cfg"
chmod 0644 "${ISO_DIR}/boot/vmlinuz" "${ISO_DIR}/boot/initrd.img" "${ISO_DIR}/boot/grub/grub.cfg"

# Rimuove kernel/initrd duplicati da /boot dentro lo squashfs per ridurre il peso dell'ISO
rm -rf "${CHROOT_DIR}/boot/"*

mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/live/filesystem.squashfs" \
    -comp xz \
    -Xbcj x86 \
    -b 1M \
    -noappend

chmod 0644 "${ISO_DIR}/live/filesystem.squashfs"

echo "==> [8/8] Generazione immagine ISO ibrida BIOS + UEFI (compatibile Rufus ISO/DD e BalenaEtcher)..."
# Prepara anche EFI standalone snello in /EFI/BOOT per piena compatibilità con Rufus in modalità ISO (FAT32)
mkdir -p "${ISO_DIR}/EFI/BOOT"
cat > "${WORK_DIR}/efi-chain.cfg" <<'EOF'
search --no-floppy --set=root --file /boot/grub/grub.cfg
configfile /boot/grub/grub.cfg
EOF
GRUB_EFI_MODS="normal configfile search search_fs_file search_fs_uuid search_label part_gpt part_msdos fat exfat ntfs iso9660 ext2 loopback gzio xzio linux all_video efi_gop efi_uga video_bochs video_cirrus video video_fb gfxterm gfxmenu font png halt reboot test echo true sleep ls cat"
grub-mkstandalone \
    -O x86_64-efi \
    --modules="${GRUB_EFI_MODS}" \
    --locales="" \
    --themes="" \
    --fonts="unicode" \
    -o "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" \
    "boot/grub/grub.cfg=${WORK_DIR}/efi-chain.cfg"
grub-mkstandalone \
    -O i386-efi \
    --modules="${GRUB_EFI_MODS}" \
    --locales="" \
    --themes="" \
    --fonts="unicode" \
    -o "${ISO_DIR}/EFI/BOOT/BOOTIA32.EFI" \
    "boot/grub/grub.cfg=${WORK_DIR}/efi-chain.cfg" || true

# Crea partizione persistente compatta RDPOS_CFG (4 MiB ext4 senza journal) integrata nell'ISO
# per salvare IP, Dominio e Utente anche su chiavette Rufus in modalità DD e BalenaEtcher
CFG_IMG="${WORK_DIR}/rdpos_cfg.img"
dd if=/dev/zero of="${CFG_IMG}" bs=1M count=4 status=none
mkfs.ext4 -F -b 1024 -O ^has_journal,^metadata_csum_seed -L RDPOS_CFG "${CFG_IMG}" >/dev/null

grub-mkrescue \
    --locales="" \
    --themes="" \
    --fonts="unicode" \
    -o "${ISO_PATH}" \
    "${ISO_DIR}" \
    -- \
    -volid "THINCLIENT_RDP" \
    -append_partition 3 0x83 "${CFG_IMG}"

(
    cd "${OUTPUT_DIR}"
    sha256sum "${ISO_NAME}" > "${ISO_NAME}.sha256"
)

ISO_SIZE="$(du -h "${ISO_PATH}" | awk '{print $1}')"
echo "=============================================================================="
echo " Compilazione completata con successo!"
echo " File ISO : ${ISO_PATH} (${ISO_SIZE})"
echo " SHA256   : $(cat "${ISO_PATH}.sha256")"
echo "=============================================================================="
