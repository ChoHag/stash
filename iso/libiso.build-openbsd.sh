#!sh

[ `id -u` = 0 ] || root() { doas "$@"; }

mount_iso() {
  # Find the first available vnd device
  _vnc=$(root vnconfig -l)
  _loop=$(echo "$_vnc" | awk -F: '/not in use/ { print $1; exit }')
 [ -n "$_loop" ] || die cannot find unused vnd device
  if [ -z "$iso_source" ]; then
    _from=$s_where/iso
    cat > "$_from" || die cannot read source iso
  else
    _from=$iso_source
  fi
  root vnconfig $_loop "${1:-$_from}"
  trap "umount_iso $_loop" ERR
  root mount /dev/${_loop}a "$iso_mount" || die mount $_from
  echo $_loop
}

umount_iso() {
  trap '' ERR
  root umount "$iso_mount"
  root vnconfig -u $1
}

sync_iso() {
  # Copy the iso contents
  root rsync -a --delete --exclude=TRANS.TBL "$iso_mount"/ "$s_where"/cd/ || die extract iso contents
  root chmod -R a+rwX "$s_where"/cd # Needs root because bsd.rd is 750
}

mount_ramdisc() {
  # Find the first available vnd device
  _img="$(load_ramdisc)"
  case "${_img%% *}" in
  none) echo none;;
  fs) echo fs $(mount_iso "${_img#* }") || exit $?;;
  cpio|cpioz)
    mkdir "$s_where"/ramdiscd
    _get=cat; [ ${_img%% *} = cpioz ] && _get='gunzip -c'
    if ! $_get "${_img#* }" | ( cd "$s_where"/ramdiscd; root cpio -id ); then # needs root for devices
      die extract ramdisc contents
    fi
    root chmod -R a+rwX "$s_where"/ramdiscd
    echo "${_img%% *}" "${_img#* }"
    ;;
  *) die undefined;;
  esac
}

umount_ramdisc() {
  case $1 in
  none);;
  fs) umount_iso $2;;
  cpio|cpioz)
    _put=cat; [ $1 = cpioz ] && _put='gzip -9c' # a moderately useful use of cat
    if on_linux; then _format=newc; else _format=sv4cpio; fi
    ( cd "$s_where"/ramdiscd; find . | cpio -o -H $_format ) | $_put > "$2" || die recreate updated ramdisc
    ;;
  *) die undefined;;
  esac
  save_ramdisc
}
