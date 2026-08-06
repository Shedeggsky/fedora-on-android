#!/usr/bin/env bash
set -e

echo "install script executed"

pkg update -y
pkg install -y proot curl wget tar xz-utils

FEDORA_DIR="$HOME/fedora-fs"
mkdir -p "$FEDORA_DIR"

ARCH=$(uname -m)
case "$ARCH" in
    aarch64) ARCH_URL="arm64" ;;
    armv7l|armv8l) ARCH_URL="armhf" ;;
    x86_64) ARCH_URL="amd64" ;;
    *) echo "[-] Unsupported arch: $ARCH"; exit 1 ;;
esac

BASE_URL="https://images.linuxcontainers.org/images/fedora/44/${ARCH_URL}/default"

echo "[+] Finding latest Fedora 44 build"
LATEST_BUILD=$(curl -sL "$BASE_URL/" | grep -oE '20[0-9]{6}_[0-9]{2}:[0-9]{2}' | tail -n 1)

if [ -z "$LATEST_BUILD" ]; then
    echo "[-] Error: Couldn't parse latest build timestamp from LXC mirror."
    exit 1
fi

ROOTFS_URL="${BASE_URL}/${LATEST_BUILD}/rootfs.tar.xz"

echo "[+] Found build: ${LATEST_BUILD}"

echo "[+] Downloading Fedora 44"
wget --show-progress -O "$HOME/rootfs.tar.xz" "$ROOTFS_URL"
mkdir -p "$FEDORA_DIR"

echo "[+] Extracting rootfs into $FEDORA_DIR"
mkdir -p "$FEDORA_DIR"
tar -xf "$TARBALL" -C "$FEDORA_DIR" --overwrite 2>/dev/null || true

mkdir -p "$FEDORA_DIR/etc"
rm -rf "$FEDORA_DIR/etc/resolv.conf"
echo "nameserver 8.8.8.8" > "$FEDORA_DIR/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "$FEDORA_DIR/etc/resolv.conf"

mkdir -p "$FEDORA_DIR/root"
chmod -R 777 "$FEDORA_DIR/root" 2>/dev/null || true
rm -f "$FEDORA_DIR/root/first_boot.sh"

cat << 'EOF' > "$FEDORA_DIR/root/first_boot.sh"
#!/bin/sh
if [ ! -f /root/.initialized ]; then
    echo "Installing necessary packages."
    dnf update -y --nodocs
    dnf install -y --nodocs tigervnc-server xterm
    dnf clean all
    touch /root/.initialized
fi
EOF

chmod +x "$FEDORA_DIR/root/first_boot.sh"

cat << 'EOF' > "$FEDORA_DIR/root/.bashrc"
# Auto-run first boot installer
if [ -f /root/first_boot.sh ]; then
    /root/first_boot.sh
    rm -f /root/first_boot.sh
fi

# Print login banner
echo ""
echo "=================================================="
echo " Fedora 44"
echo " To install packages: dnf install <package>"
echo " To start VNC server: vncserver"
echo " To exit: exit"
echo "=================================================="
echo ""
EOF

LAUNCHER="$HOME/fedora.sh"

cat << 'EOF' > "$LAUNCHER"
#!/usr/bin/env bash
FEDORA_DIR="$HOME/fedora-fs"

if [ ! -d "$FEDORA_DIR" ]; then
    echo "[-] Error: Fedora filesystem not found at $FEDORA_DIR"
    exit 1
fi

echo "[+] Starting Fedora 44"

# Execute PRoot session
#!/data/data/com.termux/files/usr/bin/bash
cd $(dirname $0)
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
command+=" --link2symlink"
command+=" -i 0:3003"
command+=" -r fedora-fs"
if [ -n "$(ls -A fedora-binds 2>/dev/null)" ]; then
    for f in fedora-binds/* ;do
        . $f
    done
fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b fedora-fs/root:/dev/shm"
## uncomment the following line to have access to the home directory of termux
#command+=" -b /data/data/com.termux/files/home:/root"
## uncomment the following line to mount /sdcard directly to /
#command+=" -b /sdcard"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/bin:/usr/bin:/sbin:/usr/sbin"
command+=" TERM=$TERM"
command+=" LANG=en_US.UTF-8"
command+=" LC_ALL=C"
command+=" LANGUAGE=en_US"
command+=" /bin/bash --login"
com="$@"
if [ -z "$1" ];then
    exec $command
else
    $command -c "$com"
fi

echo "[+] Exited Fedora."
EOF

chmod +x "$LAUNCHER"

echo ""
echo "=================================================="
echo "  Fedora 44 installed."
echo "  Start Fedora using ./fedora.sh"
echo "=================================================="

