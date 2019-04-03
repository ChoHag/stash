#!sh

: ${os_version:=$(echo "$iso_source" | sed 's/.*\(.\)\(.\)\..*$/\1.\2/')}

load_ramdisc() {
  elfrdsetroot -x "$s_where"/cd/${os_version?No version}/amd64/bsd.rd "$s_where"/ramdisc || return $?
  echo fs "$s_where"/ramdisc
}
save_ramdisc() { elfrdsetroot "$s_where"/cd/$os_version/amd64/bsd.rd "$s_where"/ramdisc; }

fiddle_serial() {
  # Enable the serial port
  echo set tty com0 >> "$s_where"/cd/etc/boot.conf
}

fiddle_autoinstall() {
  set -e
  ## Questions
  if [ -e "$LIBSTASH"/iso/installer.openbsd-$os_version ]; then
    root cp "$LIBSTASH"/iso/installer.openbsd-$os_version "$iso_mount"/auto_install.conf
  else
    root cp "$LIBSTASH"/iso/installer.openbsd "$iso_mount"/auto_install.conf
  fi
  (
    [ -n "$hostname"    ] && echo "/^System hostname/s/=.*/= $hostname/"
    [ -n "$domain"      ] && echo "/^DNS domain name/s/=.*/= $domain/"
    [ -n "$os_packages" ] && echo "/^Set name/s/=.*/= -* +b* $os_packages/" # Not sets
    [ -n "$proxy"       ] && echo "/^HTTP proxy URL/s|=.*|= $proxy|"
    if [ -n "$os_upstream" ]; then
      unproto=${os_upstream#*://}
      remote_host=${unproto%%/*}
      remote_path=${unproto#*/}
      [ "$remote_path" = "$unproto" ] && remote_path=/
      echo                        "/^HTTP Server/s/=.*/= $remote_host/"
      if [ "$os_upstream" != "${os_upstream#*/}" ]; then
        # This one's normally commented out to let the installer decide:
        echo                      '/# Server directory/s/^# //'
        echo                      "/^Server directory/s|=.*|= $remote_path|"
      fi
    fi
    if [ -e "$iso_rootkey" ]; then
      echo                        "/^Public ssh key for root account/s|=.*|= $(cat "$iso_rootkey")|"
    elif [ -e "${iso_rootkey#file:}" ]; then
      echo                        "/^Public ssh key for root account/s|=.*|= $(cat "${iso_rootkey#file:}")|"
    elif [ -n "$iso_rootkey" ]; then
      echo                        "/^Public ssh key for root account/s|=.*|= $iso_rootkey|"
    fi
    [ -n "$iso_rootpw"  ] && echo "/^Password for root account/s:=.*:= $iso_rootpw:"
    echo w
  ) | root ed -s "$iso_mount"/auto_install.conf
  root ed -s "$iso_mount"/install <<EOF # If SMP
/((NCPU > 1))/s//:/
w
EOF

  ## Disklabel
  # OpenBSD's partitioning will be performed by the installer
  get_fslayout | read-layout openbsd 0 | grep -v ^# \
    | root tee "$iso_mount"/disklabel.template >/dev/null
  # TODO: Warn if >0 or options, but only of not called from mk*
}

fiddle_hooks() {
  set -e
  if [ -n "$iso_pre_hook" -o -n "$iso_post_hook" ]; then
    # Unfortunately openbsd doesn't have a mechanism to run a custom
    # hooks before or after auto-install. Find the do_autoinstall
    # function and insert hooks immediately and before the reboot.
    [ -z "$iso_payload" ] || root cp "$iso_payload" "$iso_mount"/payload
    [ -z "$iso_pre_hook" ] || root cp "$iso_pre_hook" "$iso_mount"/mkautoiso-prehook.sh
    [ -z "$iso_post_hook" ] || root cp "$iso_post_hook" "$iso_mount"/mkautoiso-posthook.sh
    root touch "$iso_mount"/mkautoiso-prehook.sh "$iso_mount"/mkautoiso-posthook.sh
    root chmod 755 "$iso_mount"/mkautoiso-prehook.sh "$iso_mount"/mkautoiso-posthook.sh
    root ed -s "$iso_mount"/install <<EOF >/dev/null
/^do_autoinstall
a
/mkautoiso-prehook.sh
.
/exec reboot
i
/mkautoiso-posthook.sh
.
w
EOF
  fi
}

mkiso() {
  set -e
  # Create new iso
  # From src/distrib/amd64/cdfs/Makefile
  if on_openbsd; then
    OSREV=$os_version # For easier copy pasta
    mkhybrid -a -R -T -L -l -d -D -N -o "$iso_fn" -v -v                \
      -A "OpenBSD ${OSREV} amd64 autoinstall CD"                       \
      -P "Copyright (c) `date +%Y` Theo de Raadt, The OpenBSD project" \
      -p "Theo de Raadt <deraadt@openbsd.org>"                         \
      -V "OpenBSD/amd64   ${OSREV} boot-only CD"                       \
      -b ${OSREV}/amd64/cdbr -c ${OSREV}/amd64/boot.catalog            \
      "$s_where"/cd
    # -a  all-files
    # -R  Rock Ridge
    # -T  TRANS.TBL
    # -L  Allow .-file
    # -l  allow 32char
    # -d  Omit trailing period
    # -D  not use deep directory relocation, ... Use with caution.
    # -N  Omit os_version numbers ... Use with caution.
    # -o "$iso_fn"
    # -v -v verbose
    # -b  boot_image
    # -c  boot_catalog

  else
    echo Unsupported build/target combination >&2
    return 1
  fi
}
