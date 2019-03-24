#!sh

# CentOS-7-x86_64-Minimal-1708.iso
: ${os_version:=$(echo "$iso_source" | sed 's/.*CentOS-\([0-9][0-9]*\)-x86_64.*/\1/')}

fiddle_serial() {
  set -e
  # Enable the serial port
  grep -v ^# <<'EOF' | grep . | ed -s "$s_where"/cd/isolinux/isolinux.cfg
# Keep _some_ delay in case some idiot boots from this iso.
# 10ths of a second, obviously.
/^timeout/s/[0-9][0-9]*$/50/

# Why is check media still the default option? We're not installing
# from fucking floppies.
/menu default/d

/^label linux/a
  menu default
.

# The documentation claims ks.cfg merely needs to be in /. Naturally
# that doesn't actually work because that would be mad.
/append/s/$/ ks=cdrom:\/ks.cfg console=ttyS0,115200n8/
w
EOF
}

#   ? terms might be customised by mkautofs into appropriate variables
#   ? changemehost.changemedomain
#   dhcp
#   no ipv6
#   ? root password (not ssh)
#   [future: ssh pubkey]
#   serial console 115200n8
#   no user
#   UTC
#   layout (default 1 disc, wipe)
#   ? proxy
#   ? repo
#   ? packages
fiddle_autoinstall() { # inc. layout, halt
  set -e
  if [ -e "$LIBSTASH"/iso/installer.devuan-$os_version ]; then
    cp "$LIBSTASH"/iso/installer.devuan-$os_version "$s_where"/cd/ks.cfg
  else
    cp "$LIBSTASH"/iso/installer.devuan "$s_where"/cd/ks.cfg
  fi
}

fiddle_hooks() {
  set -e
  [ -n "$iso_payload" ] && cp "$iso_payload" "$s_where"/cd/payload
  [ -n "$iso_pre_hook" ] && cp "$iso_pre_hook" "$s_where"/cd/mkautoiso-prehook.sh
  [ -n "$iso_post_hook" ] && cp "$iso_post_hook" "$s_where"/cd/mkautoiso-posthook.sh
  touch "$s_where"/cd/mkautoiso-{pre,post}hook.sh
  root chmod 755 "$s_where"/cd/mkautoiso-{pre,post}hook.sh
}

mkiso() {
  set -e
  # From god-knows s_where:
  # mkisofs -o "$s_where"/auto.iso  \
  #   -b isolinux/isolinux.bin    \
  #   -c isolinux/boot.cat        \
  #   -no-emul-boot               \
  #   -boot-load-size 4           \
  #   -boot-info-table            \
  #   -V "CentOS $os_version x86_64" \
  #   -RJT                        \
  #   "$s_where"/cd

  if on_openbsd; then
    if ! which xorriso >/dev/null 2>&1; then
      echo mkhybrid on OpenBSD is incompatible with isolinux >&2
      return 1
    fi

    xorriso --as mkisofs -f -RJT                       \
      -V "CentOS $os_version x86_64"                   \
      -b isolinux/isolinux.bin -c isolinux/boot.cat    \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
      -o "$iso_fn" "$s_where"/cd

  else
    echo Unsupported build/target combination >&2
    return 1
  fi
}
