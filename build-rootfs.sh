#!/bin/bash
# apt-get install binfmt-support qemu qemu-user-static debootstrap kpartx lvm2 dosfstools

deb_mirror="http://deb.debian.org/debian/"

deb_release="stretch"

buildenv="/root/buildimage"
rootfs="${buildenv}/rootfs"

mydate=`date +%Y%m%d`

ROOT_PASSWD="root"
TIMEZONE="Europe/Berlin"
KEYBOARD_CONFIGURATION="de"

if [ $EUID -ne 0 ]; then
  echo "this tool must be run as root"
  exit 1
fi

rm -rf $rootfs
mkdir -p $rootfs

cd $rootfs

debootstrap --foreign --arch armhf $deb_release $rootfs $deb_local_mirror
cp /usr/bin/qemu-arm-static usr/bin/
LANG=C chroot $rootfs /debootstrap/debootstrap --second-stage



cat << EOF > etc/fstab
proc            /proc           proc    defaults        0       0
/dev/sda1  /boot           vfat    defaults        0       0
EOF

echo "empc-aimx6" > etc/hostname

NETWORKETH0="192.100.0"

cat << EOF > etc/network/interfaces
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet static
        address $NETWORKETH0.1
        network $NETWORKETH0.0
        netmask 255.255.255.0
        gateway $NETWORKETH0.254
        broadcast $NETWORKETH0.255
EOF


cat << EOF > debconf.set
console-common    console-data/keymap/policy      select  Select keymap from full list
console-common  console-data/keymap/full        select  de-latin1-nodeadkeys
EOF


cat << EOF > etc/apt/sources.list
deb $deb_mirror $deb_release main contrib non-free
deb-src $deb_mirror $deb_release main contrib non-free

EOF


cat << EOF > third-stage
#!/bin/bash
debconf-set-selections /debconf.set
rm -f /debconf.set
apt-get update

DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install git-core binutils ca-certificates

# Configure timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
# Configure keyboard
sed -i 's/XKBLAYOUT=\"us\"/XKBLAYOUT=\"${KEYBOARD_CONFIGURATION}\"/g' /etc/default/keyboard
# Set root password
echo -e "${ROOT_PASSWD}\n${ROOT_PASSWD}" | passwd root
rm -f third-stage

EOF


chmod +x third-stage
LANG=C chroot $rootfs /third-stage




cat << EOF > tmp/downloadsources
#!/bin/bash

mkdir -p /rootfs-src
cd /rootfs-src
# ${Source} doesn't always show the source package name, ${source:Package} does.
# Multiple packages can have the same source, sort -u eliminates duplicates.
dpkg-query -f '${source:Package}\n' -W | sort -u | while read p; do
    mkdir -p $p
    pushd $p

    # -qq very quiet, pushd provides cleaner progress.
    # -d download compressed sources only, do not extract.
    apt-get -qq -d source $p

    popd
done
EOF

chmod +x tmp/downloadsources
LANG=C chroot $rootfs /tmp/downloadsources



cat << EOF > cleanup
#!/bin/bash
apt-get clean
rm -f cleanup
#rm -f /usr/bin/qemu-arm-static
EOF

chmod +x cleanup
LANG=C chroot $rootfs /cleanup


mv rootfs-src ../rootfs-src

cd

echo "done."
