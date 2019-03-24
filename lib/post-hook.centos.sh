#!sh

# Fixup packages
inroot rpm -e \$(inroot rpm -qa | grep firmware)
inroot yum -y remove alsa-lib authconfig biosdevname                   \
btrfs-progs chrony dbus-glib dbus-python dmidecode dnsmasq ebtables    \
firewalld firewalld-filesystem fxload glib-networking gnutls           \
gobject-introspection hwdata iprutils ipset{,-libs} irqbalance jansson \
kbd kbd-legacy kbd-misc kernel-tools kernel-tools-libs kexec-tools     \
libdaemon libdrm libgudev1 libmodman libndp libnl3 libnl3-cli libpcap  \
libpciaccess libproxy libselinux-python libselinux-utils libsoup       \
libsysfs libteam lsscsi lzo mariadb-libs microcode_ctl mozjs17 nettle  \
NetworkManager-libnm NetworkManager{,-wifi,-tui,-team} newt{,-python}  \
numactl-libs parted pciutils plymouth-core-libs plymouth{,-scripts}    \
policycoreutils polkit{,-pkla-compat} postfix ppp pygobject3-base      \
python-configobj python-decorator python-firewall python-perf          \
python-pyudev python-slip python-slip-dbus rdma rootfiles              \
selinux-policy{,-targeted} slang snappy teamd trousers tuned virt-what \
wpa_supplicant xfsprogs

inroot yum -y install net-tools telnet bc ed nc tmux tcpdump

# Disable useless shit which can't be uninstalled
inroot systemctl disable lvm2-lvmetad.socket
inroot systemctl disable lvm2-lvmpolld.socket
inroot systemctl disable dbus.{service,socket}
inroot systemctl disable lvm2-monitor
inroot systemctl disable dm-event
printf '/use_lvmetad.*=/s/.\$/0/\nw\n' | inroot ed -s /etc/lvm/lvm.conf # It just won't die!

# Fixup boot
inroot ed -s /etc/default/grub <<'EOF'
/GRUB_TERMINAL/s/=.*/="serial"/
/GRUB_CMDLINE_LINUX/s|=.*|="rd.lvm.lv=os/root rd.lvm.lv=os/swap0 rootflags=noatime,nodiratime,data=journal,errors=remount-ro console=ttyS0"|
EOF
inroot grub2-mkconfig > $_top/boot/grub2/grub.cfg
kernel=\$(ls $_top/boot/vmlinux* | grep -v rescue | sed s/.*vmlinuz-// | sort | tail -n1)
modules="\$( find $_top/lib/modules/\$kernel/ -name \*.ko.* | sed s,.*/,,\\;s/\.ko.*// )"
inroot dracut -f --add-drivers "\$modules" "\$kernel" # fucking hell
ln -sf /dev/null $_top/etc/systemd/system/getty@tty1.service
ln -sf /dev/null $_top/etc/systemd/system/serial-getty@ttyS0.service

# Fixup random
rm -f $_top/var/lib/systemd/random-seed
touch $_top/var/lib/systemd/random-seed
chmod 600 $_top/var/lib/systemd/random-seed

# Fixup /etc
rm -f $_top/etc/skel/.Xdefaults
mkdir -p $_top/etc/skel/.ssh
echo '# Starts empty' > $_top/etc/skel/.ssh/authorized_keys
chmod 700 $_top/etc/skel/.ssh
chmod 400 $_top/etc/skel/.ssh/authorized_keys
cp "$LIBSTASH"/rc.local.firsttime $_top/etc/rc.local
printf '/^root:/s/:[^:]*:/:${rootpw:-*************}:/\nw' | inroot ed -s /etc/shadow

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
echo 'LANG="C"' > $_top/etc/locale.conf
rm -f $_top/etc/aliases.db
inroot yum -y clean all
rm -fr $_top/var/cache/yum
rm -fr $_top/tmp/*
