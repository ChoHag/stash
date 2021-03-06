#!sh

# devuan_ascii_2.0.0_amd64_netinst.iso
: ${os_version:=$(echo "$iso" | sed 's/.*devuan_[a-z]+_\([0-9]+\.[0-9]+\)_amd64_netinst\.iso$/\1/')}

load_ramdisc() { echo cpioz "$s_where"/cd/install.amd/initrd.gz; }
save_ramdisc() { :; }

fiddle_serial() {
  # Enable the serial port
  cat > "$s_where"/cd/isolinux/isolinux.cfg <<EOF
prompt 0
timeout 0
default auto

label auto
  menu label Devuan auto installer
  kernel /install.amd/vmlinuz
  append initrd=/install.amd/initrd.gz console=ttyS0,115200n8 expert
  # auto=yes
  # domain/hostname=
  # keymap=
  # preseed-md5=
EOF
}

# x - done; y - maybe done
# ? terms might be customised by mkautofs into appropriate variables
# y ? changemehost.changemedomain
# y dhcp
#   no ipv6
# y ? root password (not ssh)
#   [future: ssh pubkey]
# x serial console 115200n8
# x no user
# x UTC
# y layout (default 1 disc, wipe)
# y ? proxy
# y ? repo
#   ? packages
fiddle_autoinstall() { # inc. layout, halt
  if [ -e "$LIBSTASH"/iso/installer.devuan-$os_version ]; then
    cp "$LIBSTASH"/iso/installer.devuan-$os_version "$s_where"/ramdiscd/preseed.cfg

  else
    cp "$LIBSTASH"/iso/installer.devuan "$s_where"/ramdiscd/preseed.cfg
  fi
  (
    [ -n "$hostname"    ] && echo "g/changemehost/s//${hostname%%.*}/"
    [ -n "$hostname"    ] && echo "g/changemedomain/s//${hostname#.*}/"
    [ -n "$os_packages" ] && echo "g/pkgsel.include/s/[^[:space:]]*$/$os_packages/"
    [ -n "$proxy"       ] && echo "g/mirror.http.proxy/s|[^[:space:]]*$|$proxy|"
    if [ -n "$os_upstream" ]; then
      unproto=${os_upstream#*://}
      remote_host=${unproto%%/*}
      remote_path=${unproto#*/}
      [ "$remote_path" = "$unproto" ] && remote_path=/
                             echo "g/mirror.http.hostname/s/[^[:space:]]*$/$remote_host/"
                             echo "g/mirror.http.directory/s|[^[:space:]]*$|/$remote_path|"
    fi
    [ -n "$iso_rootpw"  ] && echo "g/root-password-crypted/s|[^[:space:]]*$|$iso_rootpw|"
    echo w
  ) | ed -s "$s_where"/ramdiscd/preseed.cfg >&2
    # console not on ttyS0
    # sets up ipv6
    # layout
    # installs laptop-detect and probably other shit
    # grub device

    # This command is run immediately before the partitioner starts. It may be
    # useful to apply dynamic partitioner preseeding that depends on the state
    # of the disks (which may not be visible when preseed/early_command runs).
    #d-i partman/early_command \
    #       string debconf-set partman-auto/disk "$(list-devices disk | head -n1)"
}

fiddle_hooks() {
  [ -n "$iso_payload" ] && cp "$iso_payload" "$s_where"/ramdiscd/payload
  [ -n "$iso_pre_hook" ] && cp "$iso_pre_hook" "$s_where"/ramdiscd/mkautoiso-prehook.sh
  cat >"$s_where"/ramdiscs/mkautoiso-posthook.sh <<EOF
#!/bin/sh
if [ -n "$proxy" ]; then
  touch \$_top/etc/environment
  for _p in ftp http https; do
    echo g/\${_p}_proxy=/d
    echo \\\$a
    echo \${_p}_proxy=$proxy
    echo .
  done | ed -s \$_top/etc/environment
fi
EOF
  [ -n "$iso_post_hook" ] && cat "$iso_post_hook" >>"$s_where"/ramdiscd/mkautoiso-posthook.sh
  touch "$s_where"/ramdiscd/mkautoiso-{pre,post}hook.sh
  root chmod 755 "$s_where"/ramdiscd/mkautoiso-{pre,post}hook.sh
}

mkiso() {
  # Create new iso
  # According to https://wiki.debian.org/DebianInstaller/Preseed/EditIso
  #genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \                                                    
  #          -no-emul-boot -boot-load-size 4 -boot-info-table \                                                           
  #          -o "$iso_fn" "$s_where"/cd

  if on_openbsd; then
    which xorriso >/dev/null 2>&1 || die mkhybrid on OpenBSD is incompatible with isolinux
    # Specifically, it needs to do this from libisofs:
    # int make_boot_info_table(uint8_t *buf, uint32_t pvd_lba, uint32_t boot_lba, uint32_t imgsize)
    #     info = (struct boot_info_table *) (buf + 8);
    #     uint32_t checksum = 0;
    #     int offset = 64;
    #     for (; offset <= imgsize - 4; offset += 4)
    #         checksum += iso_read_lsb(buf + offset, 4);
    #     if (offset != imgsize)
    #         checksum += iso_read_lsb(buf + offset, imgsize - offset);
    #     iso_lsb(info->bi_pvd, pvd_lba, 4);   // pvd_lba = t->ms_block + (uint32_t) 16,
    #     iso_lsb(info->bi_file, boot_lba, 4); // boot_lba = t->bootsrc[idx]->sections[0].block,
    #     iso_lsb(info->bi_length, imgsize, 4);
    #     iso_lsb(info->bi_csum, checksum, 4);
    #     memset(buf + 24, 0, 40);

    xorriso --as mkisofs -f -r -J                      \
      -b isolinux/isolinux.bin -c isolinux/boot.cat    \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
      -o "$iso_fn" "$s_where"/cd
    # -r  Rock-ridge with sane file UIDs
    # -J  Joliet
    # -b  boot_image
    # -c  boot_catalog
    # -no-emul-boot    Override boot-emulation detection (against iso spec)
    # -boot-load-size  ... workaround above hack
    # -boot-info-table ... accomodate linux

  else
    die_unsupported build/target combination
  fi
}
