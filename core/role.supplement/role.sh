#!sh
# Role methods to load more role definitions

role_settings() {
  role var searched # ro
}

role_apply() {
  if [ -n "$supplement_searched" ] || ! on_firsttime; then return; fi
  role var searched true
  for _from in $(echo "$stash_from" | tr , ' '); do
    LOG_info Looking for stash from $_from
    case $_from in
    usb)
      case $(on) in
      openbsd)
        _usbdev=/dev/$(dmesg | grep -E ^sd[0-9]+: | cut -d: -f1 | tail -n1)
        _usbpart=${_usbdev}i
        ;;
      debian|devuan|centos)
        _usbdev=/dev/disk/by-path/*-usb-*:?
        _usbpart=${_usbdev}-part1
        [ "$_usbdev" = "${_usbdev#* }" ] || fail Too many usb devices
        ;;
      esac
      _r=
      if mount -r $_usbpart /mnt; then
        if _verify_stash </mnt/stash.tgz
        then _r=0; else _r=$?; fi
        umount /mnt
      fi
      [ -z "$_r" ] || return $_r
      ;;

    *) die undefined;;
    esac
  done
}

_verify_stash() {
  _sgexe=signify
  on_deb && _sgexe=signify-openbsd # doesn't support -z or -t
  _zvexe=zverify
  which $_zvexe >/dev/null 2>&1 || _zvexe="perl $stash/role.supplement/zverify"
  case $sign in
  signify)
    if on_openbsd; then
      $_sgexe -Vz -t stash -m- -x- | tar -C /root/stash -xzf-
    else
      $_zvexe $_sgexe -Vq -p /etc/signify/${stash_pubkey##*/} -m- -x -- | tar -C /root/stash -xzf-
    fi
    ;;
  gpg) HOME=${HOME:-/root} $_zvexe gpg --verify -- - | tar -C /root/stash -xzf-;;
  *)   die_unsupported verify $sign;;
  esac
}
