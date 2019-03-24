#!sh

# Fixup networking
if ! grep -qF . $_top/etc/hostname; then
  echo ${hostname:-changemehost}.${domain:-changemedomain} > $_top/etc/hostname
fi

cat > $_top/etc/network/interfaces <<'EOF'
auto lo eth0
iface lo inet loopback
iface eth0 inet dhcp
EOF

# Fixup packages
cat > $_top/etc/apt/apt.conf.d/no-recommends <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

inroot debconf-set-selections <<'EOF'
debconf debconf/priority select low
debconf debconf/frontend select Teletype
EOF

_apt() {
  # from /bin/apt-install
  inroot debconf-apt-progress --no-progress --logstderr -- apt-get -q -y "$@"
}

#</dev/null inroot apt-get -y --purge remove nano
#</dev/null inroot apt-get update
#</dev/null inroot apt-get -y dist-upgrade
#apt-install --allow-remove
_apt update
_apt dist-upgrade
_apt --purge install \
nano-           \
bc              \
ed              \
ifupdown        \
iotop           \
isc-dhcp-client \
less            \
logrotate       \
lvm2            \
man             \
net-tools       \
netcat-openbsd  \
nvi             \
perl            \
rsyslog         \
tcpdump         \
telnet          \
tmux

# Fixup boot
# Configure kernel & boot loader (amazon only 'supports' grub)
if mount | grep -qwF /mnt/boot; then
  rm -f $_top/{vmlinuz,initrd.img}{,.old}
  (cd $_top/boot; root ln -sf `ls vmlinuz-*|sort|tail -n1` vmlinuz)
  (cd $_top/boot; root ln -sf `ls initrd.img-*|sort|tail -n1` initrd.img)
fi

# TODO: fsopts for /
cat > $_top/etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR=Debian
GRUB_DISABLE_LINUX_UUID=true
GRUB_DISABLE_RECOVERY=true
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX="rootflags=noatime,nodiratime,data=journal,errors=remount-ro console=ttyS0,115200n8"
EOF
inroot update-grub

# Look ma! No systemd!
inroot ed -s /etc/inittab <<'EOF'
# Disable virtual console tty
/.*tty[0-9]*$/s//#stash#&/
#
# Enable serial port tty
/#.*ttyS0/s/#*//
/9600/s//115200/
#
w
EOF

# Fixup random
rm -f $_top/var/lib/urandom/random-seed
touch $_top/var/lib/urandom/random-seed
chmod 600 $_top/var/lib/urandom/random-seed

# Fixup /etc
rm -f $_top/etc/skel/.Xdefaults
mkdir -p $_top/etc/skel/.ssh
echo '# Starts empty' > $_top/etc/skel/.ssh/authorized_keys
chmod 700 $_top/etc/skel/.ssh
chmod 400 $_top/etc/skel/.ssh/authorized_keys
cp $_top/root/rc.local.firsttime $_top/etc/rc.local

# Fixup ssh
cat >> $_top/etc/ssh/ssh_config <<'EOF'
Host *
  CheckHostIP yes
  StrictHostKeyChecking yes
EOF

cat >> $_top/etc/ssh/sshd_config <<'EOF'
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
PermitRootLogin without-password # TODO: check this: Not prohibit-password yet; debian needs to catch up
UsePAM yes
EOF

# Fixup misc
# Miscellaneous shite that shouldn't be necessary, but linux
inroot groupadd -r wheel # Richard Stallman is a twat
rm -f $_top/root/.bashrc /root/.profile
# It's 2018 for fuck's sake
echo blacklist floppy > $_top/etc/modprobe.d/floppy.conf
# I'd like to not do this but if it's not done right here something'll
# do it wrong later.
_apt install locales
inroot update-locale LANG=C.UTF-8 LC_CTYPE=C
_apt clean
rm -fr $_top/tmp/*
