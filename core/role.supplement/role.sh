#!sh
# Role methods to load more role definitions

role_settings() {
  on_openbsd || die_unsupported
  role var searched # ro
}

role_apply() {
  set -e
  if [ -n "$supplement_searched" ] || ! on_firsttime; then return; fi
  role var searched true
  _usbdev=$(dmesg | grep -E ^sd[0-9]+: | cut -d: -f1 | sort -u | tail -n1)
  for _from in $(echo "$stash_from" | tr , ' '); do
    LOG_info Looking for stash from $_from
    case $_from in
    usb)
      _r=
      if mount -r /dev/${_usbdev}a /mnt; then
        if _validate_stash < /mnt/stash.tgz
        then _r=0; else _r=$?; fi
        umount /mnt
      fi
      [ -z "$_r" ] || return $_r
      ;;

    *) ...;;
    esac
  done
}

_validate_stash() { signify -Vz -t stash | tar -C /root/stash -xzf-; }
  
