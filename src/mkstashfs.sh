#!/bin/sh

usage() {
  echo \?
  exit ${1:-0}
}

debug= s_wherein= s_where=/tmp/nowhere
while getopts hDw: _opt; do case "$_opt" in
  \?) usage 1;;
  h) echo "Don't panic!"; usage;;
  D) debug=true;;
  w) s_wherein=$OPTARG;;
esac; done
shift $(($OPTIND-1))

size=${1:-10m}
case $size in
*[Mm]) bytes=$((${size%?} * 1048576));;
*[Kk]) bytes=$((${size%?} * 1024));;
*[Bb]) bytes=${size%?};;
*)     bytes=$size;;
esac

# Copied from libstash.sh to keep this small
s_where=$(mktemp -d ${s_wherein:+-p "$s_wherein"})
[ -n "$debug" ] || trap 'rm -fr "$s_where" &' EXIT
_get_on() {
  [ -n "$s_on" ] && return
    if [ -e /etc/centos-release ]; then s_on=centos
  elif [ -e /etc/debian_version ]; then s_on=debian
  elif [ -e /etc/devuan_version ]; then s_on=devuan
  elif [ "`uname`" = OpenBSD ];    then s_on=openbsd
  else die_unsupported unknown; fi
}
on_centos()  { _get_on && [ $s_on = centos ]; }
on_debian()  { _get_on && [ $s_on = debian ]; }
on_devuan()  { _get_on && [ $s_on = devuan ]; }
on_deb()     { on_debian || on_devuan; }
on_openbsd() { _get_on && [ $s_on = openbsd ]; }
on_linux()   { on_deb || on_centos; }
on_bsd()     { on_openbsd; }
on_systemd() { die_unsupported; }

exec 3>&1 >&2

die() { echo "Failed: $@; aborting" >&2; exit 1; }

dd if=/dev/zero of="$s_where"/fs.img bs=1 count=1 seek=$(($bytes - 1)) || die create "$s_where"/fs.img

if on_openbsd; then
  loop=$(vnconfig -l | awk -F: '/not in use/ { print $1; exit }')
  [ -n "$loop" ] || die cannot find unused vnd device
  (
    set -e
    vnconfig $loop "$s_where"/fs.img
    size=$(fdisk $loop | tr -d [] | awk '/^Disk/ {print $5}')
    printf 'edit 0\n6\nn\n128\n%u\nq\n' $(($size-128)) | fdisk -e $loop
    newfs_msdos -F 16 /dev/r${loop}i
    mount /dev/${loop}i /mnt
    cat >/mnt/stash.tgz
  )
  _r=$?
  umount /mnt
  vnconfig -u $loop
  [ $_r = 0 ] || die mkfs
fi

cat "$s_where"/fs.img >&3
