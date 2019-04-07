#!sh

# VM operations:
#  upload/create block device
#  launch/stop/connect
#  declare permanent
#
# Notion of a VM:
#  boot method (block[s]/net/kernel)
#  block devices (& type - hd/cd/usb)
#  'local' net device[s]
#  'bridged' net device[s]
#  'unattached' net device[s]
#  ram
#  (not openbsd) core count

_load_hvm() {
  local _hvm=$1 _transient=$2
  [ -e "$LIBSTASH"/lib/libstash-hvm-$_hvm.sh ] || die_unsupported hypervisor $_hvm
  if [ -n "$_transient" ]; then
    hvm_make_transient() { [ "${hvm_transient:-always}" != never ]; }
  else
    hvm_make_transient() { [ "${hvm_transient:-never}" != never ]; }
  fi
  . "$LIBSTASH"/lib/libstash-hvm-$_hvm.sh
}

hvm_declare() {
  local _name=$1; shift
  if [ $_name != "${_name#_}" ]; then
    echo The first argument to hvm_declare must be the VM name >&2
    return 1
  fi
  hvm_clear $_name
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts ab:c:d:lmr:u: _opt; do case $_opt in
  a) hvm_set_val         $_name auto 1;;
  b) hvm_network_bridged $_name "$OPTARG";;
  c) hvm_set_cores       $_name "$OPTARG";;
  d) hvm_attach_disc     $_name "$OPTARG";;
  l) hvm_network_local   $_name;;
  m) hvm_network_misc    $_name;;
  r) hvm_attach_cd       $_name "$OPTARG";;
  u) hvm_attach_usb      $_name "$OPTARG";;
  esac; done
  shift $(($OPTIND-1))
  hvm_set_val $_name ram "$1"
  hvm_set_val $_name cores "$2"
  hvm_set_val $_name defined 1
}

## Attachments

hvm_attach_block() {
  local _name=$1 _path=$2 _type=$3
  local _count=$(hvm_get_val $_name ${_type:-disc}_count)
  : ${_count:=0}
  hvm_set_val $_name ${_type:-disc}_${_count}_path "$_path"
  hvm_set_val $_name ${_type:-disc}_count $(($_count+1))
}

hvm_network_misc() {
  local _name=$1 _id=$2 _type=$3
  local _count=$(hvm_get_val $_name ${_type:-misc}_count)
  hvm_set_val $_name ${_type:-misc}_${_count}_settings "${_id:-yes}"
  hvm_set_val $_name ${_type:-misc}_count $(($_count+1))
}

hvm_attach_cd() { hvm_attach_block "$@" cd; }
hvm_attach_disc() { hvm_attach_block "$@"; }
hvm_attach_usb() { hvm_attach_block "$@" usb; }

hvm_network_bridged() { hvm_network_misc "$@" bridged; }
hvm_network_local() { hvm_network_misc "$@" '' local; }

## Variables

hvm_clear() {
  local _name=$(echo "$1" | tr - _) _var=
  for _var in auto cores ram template; do hvm_set_val $_name $_var ''; done
  for _var in cd disc usb \
              bridged local misc; do hvm_set_val $_name ${_var}_count 0; done
}

hvm_get_all() { local _name=$(echo $1 | tr - _); set | grep ^hvm_def_$_name; }
hvm_get_val() { local _name=$(echo $1 | tr - _); eval echo \"\$hvm_def_${_name}_${2}\"; }
hvm_set_val() { local _name=$(echo $1 | tr - _); eval hvm_def_${_name}_${2}=\$3; }
