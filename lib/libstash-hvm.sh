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
  hvm_ready $_name
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts ab:c:d:lmr:u: _opt; do case $_opt in
  a) hvm_set_val         $_name auto 1;;
  b) hvm_network_bridged "$OPTARG";;
  c) hvm_set_cores       "$OPTARG";;
  d) hvm_attach_disc     "$OPTARG";;
  l) hvm_network_local;;
  m) hvm_network_misc;;
  r) hvm_attach_cd       "$OPTARG";;
  u) hvm_attach_usb      "$OPTARG";;
  esac; done
  shift $(($OPTIND-1))
  hvm_set_val $_name ram "$1"
  hvm_set_val $_name cores "$2"
  hvm_set_val $_name defined 1
}

## Attachments

hvm_attach_block() {
  local _name=$hvm_defining
  if [ $# -eq 3 ]; then _name=$1; shift; fi
  local _path=$1 _type=$2
  local _count=$(hvm_get_val $_name ${_type}_count)
  : ${_count:=0}
  hvm_set_val $_name ${_type}_${_count}_path "$_path"
  hvm_set_val $_name ${_type}_count $(($_count+1))
}

hvm_network() {
  local _type=$1 _name=$hvm_defining
  shift
  if [ \( "$_type" = bridged -a $# -ge 2 \) \
    -o \( "$_type" != bridged -a $# -ge 1 \) ]; then
    _name=$1
    shift
  fi
  local _id=$1 _count=$(hvm_get_val $_name ${_type}_count)
  hvm_set_val $_name ${_type}_${_count}_settings "${_id:-yes}"
  hvm_set_val $_name ${_type}_count $(($_count+1))
}

hvm_attach_cd() { hvm_attach_block "$@" cd; }
hvm_attach_disc() { hvm_attach_block "$@" disc; }
hvm_attach_usb() { hvm_attach_block "$@" usb; }

hvm_network_bridged() { hvm_network bridged "$@"; }
hvm_network_local() { hvm_network local "$@"; }
hvm_network_misc() { hvm_network misc "$@"; }

## Variables

hvm_ready() {
  hvm_defining=$1
  local _name=$(echo "$1" | tr - _) _var=
  for _var in auto cores ram template; do hvm_set_val $_name $_var ''; done
  for _var in cd disc usb \
              bridged local misc; do hvm_set_val $_name ${_var}_count 0; done
}

hvm_get_all() { local _name=$(echo $1 | tr - _); set | grep ^hvm_def_$_name; }
hvm_get_val() { local _name=$(echo $1 | tr - _); eval echo \"\$hvm_def_${_name}_${2}\"; }
hvm_set_val() { local _name=$(echo $1 | tr - _); eval hvm_def_${_name}_${2}=\$3; }
