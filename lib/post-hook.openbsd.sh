#!sh

# Fixup fstab
# TODO: put this xx thing into the disclabel parser
echo '/altroot/s/ffs.*/ffs xx 0 0/\nw' | inroot ed -s /etc/fstab || true
for _label in $_top/root/disklabel.*; do
  [ "${_label%.0}" = "$_label" ] || continue
  LOG_info labelling disc ${_label##*.}
  fdisk -iy sd${_label##*.}
  disklabel -T $_label -F /tmp/fstab.new -w -A sd${_label##*.}
  cat /tmp/fstab.new >> $_top/etc/fstab
done

while read _disc _part _extra; do
  _re=
  if [ $_disc = 0 ]; then umount /dev/sd$_disc$_part; _re=re; fi # already mounted
  LOG_info ${_re}formatting sd$_disc$_part
  inroot newfs -q $_extra /dev/rsd$_disc$_part
done < $_top/root/format-options

# Fixup networking
# Network correctly configured by installer except autoinstall doesn't
# ask for domain name
_fqdn="%s/${hostname:-changemehost}[a-z.-]*/${hostname:-changemehost}.${domain:-changemedomain}/"
inroot printf '%s\nw\n' "$_fqdn" | inroot ed -s /etc/myname || true
inroot printf '%s\nw\n' "$_fqdn" | inroot ed -s /etc/rc.firsttime || true
# TODO, perhaps in firsttime? mv /etc/hostname.vio0 to /etc/hostname.<what>0?

# Fixup packaging
if [ -n "$packages" ]; then inroot pkg_add $packages </dev/null; fi

# Fixup /etc
rm -f $_top/etc/skel/.Xdefaults
mkdir -p $_top/etc/skel/.ssh
echo '# Starts empty' > $_top/etc/skel/.ssh/authorized_keys
chmod 700 $_top/etc/skel/.ssh
chmod 400 $_top/etc/skel/.ssh/authorized_keys
echo /etc/skel/.Xdefaults > $_top/etc/sysmerge.ignore

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
EOF

cat >> $_top/etc/rc.firsttime <<'EOF'
auto_halt() {
  echo Suspending reboot until KARL is finished.
  # Wait until OpenBSD has finished relinking the kernel or it will
  # fail to do so again.
  # Additionally this script's output is being collected to mail it to
  # root so ensure the background process is fully detached.
  sh -c '
    s=5; while sleep $s && pgrep -qflx /bin/ksh./usr/libexec/reorder_kernel; do s=1; done
    halt -p
  ' <&- >&- 2>&- &
}
EOF
