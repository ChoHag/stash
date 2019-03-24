#!sh

[ `id -u` = 0 ] || root() { doas "$@"; }

mount_iso() {
  set -e
  # Find the first available vnd device
  _vnc=$(root vnconfig -l)
  _loop=$(echo "$_vnc" | awk -F: '/not in use/ { print $1; exit }')
  if [ -z "$iso_source" ]; then
    _from=$s_where/iso
    cat > "$_from"
  else
    _from=$iso_source
  fi
  root vnconfig $_loop "${1:-$_from}"
  trap "umount_iso $_loop" ERR
  root mount /dev/${_loop}a "$iso_mount"
  echo $_loop
}

umount_iso() {
  set +e
  trap '' ERR
  root umount "$iso_mount"
  root vnconfig -u $1
}

sync_iso() {
  set -e
  # Copy the iso contents
  root rsync -a --delete --exclude=TRANS.TBL "$iso_mount"/ "$s_where"/cd/
  root chmod -R a+rwX "$s_where"/cd # Needs root because bsd.rd is 750
}

mount_ramdisc() {
  set -e
  # Find the first available vnd device
  _img="$(load_ramdisc)"
  case "${_img%% *}" in
  none) echo none;;
  fs) echo fs $(mount_iso "${_img#* }");;
  cpio|cpioz)
    mkdir "$s_where"/ramdiscd
    _get=cat; [ ${_img%% *} = cpioz ] && _get='gunzip -c'
    $_get "${_img#* }" | ( cd "$s_where"/ramdiscd; root cpio -id ) # needs root for devices
    root chmod -R a+rwX "$s_where"/ramdiscd
    echo "${_img%% *}" "${_img#* }"
    ;;
  *) ...;;
  esac
}

umount_ramdisc() {
  set -e
  case $1 in
  none);;
  fs) umount_iso $2;;
  cpio|cpioz)
    _put=cat; [ $1 = cpioz ] && _put='gzip -9c' # a moderately useful use of cat
    if on_linux; then _format=newc; else _format=sv4cpio; fi
    ( cd "$s_where"/ramdiscd; find . | cpio -o -H $_format ) | $_put > "$2"
    ;;
  *) ...;;
  esac
  save_ramdisc
}
