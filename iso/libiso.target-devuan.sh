#!sh

# devuan_ascii_2.0.0_amd64_netinst.iso
: ${os_version:=$(echo "$iso" | sed 's/.*devuan_[a-z]+_\([0-9]+\.[0-9]+\)_amd64_netinst\.iso$/\1/')}

load_ramdisc() { echo cpioz "$s_where"/cd/install.amd/initrd.gz; }
save_ramdisc() { :; }

fiddle_serial() {
  set -e
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

#   ? terms might be customised by mkautofs into appropriate variables
# y ? changemehost.changemedomain
# y dhcp
#   no ipv6
#   ? root password (not ssh)
#   [future: ssh pubkey]
# y serial console 115200n8
# x no user
# x UTC
#   layout (default 1 disc, wipe)
#   ? proxy
#   ? repo
#   ? packages
fiddle_autoinstall() { # inc. layout, halt
  set -e
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
    [ -n "$iso_rootpw"  ] && echo "g/root-password-crypted/s/[^[:space:]]*$/$iso_rootpw/"
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
  set -e
  [ -n "$iso_payload" ] && cp "$iso_payload" "$s_where"/ramdiscd/payload
  [ -n "$iso_pre_hook" ] && cp "$iso_pre_hook" "$s_where"/ramdiscd/mkautoiso-prehook.sh
  [ -n "$iso_post_hook" ] && cp "$iso_post_hook" "$s_where"/ramdiscd/mkautoiso-posthook.sh
  touch "$s_where"/ramdiscd/mkautoiso-{pre,post}hook.sh
  root chmod 755 "$s_where"/ramdiscd/mkautoiso-{pre,post}hook.sh
}

mkiso() {
  set -e
  # Create new iso
  # According to https://wiki.debian.org/DebianInstaller/Preseed/EditIso
  #genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \                                                    
  #          -no-emul-boot -boot-load-size 4 -boot-info-table \                                                           
  #          -o "$iso_fn" "$s_where"/cd

  if on_openbsd; then
    if ! which xorriso >/dev/null 2>&1; then
      echo mkhybrid on OpenBSD is incompatible with isolinux >&2
      return 1
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
    fi

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
    echo Unsupported build/target combination >&2
    return 1
  fi
}
