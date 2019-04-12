#!sh

hvm_clone() {
  local _name=$1 _src=$2
  ${hvm_remote:+ssh -t $hvm_remote} $hvm_root ${_src:+snapshot_name=$_src} ${hvm_class:-nbs}vm $_name clone
}

hvm_create() {
  local _name=$1 _size=$2 _id=${3:-0} # nbsvm can only create the 'next' drive; ignore _id
  ${hvm_remote:+ssh -t $hvm_remote} $hvm_root drive_size=$_size ${nbsvm_class:-nbs}vm $_name newimg
}

hvm_launch() {
  local _name=$1
  shift

  local _cores= _network= _opt= _ram= _usbo='-cdrom ' _waiting=
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts c:n:r:u _opt; do case "$_opt" in
    c) _cores=$OPTARG;;
    n) _network=$OPTARG;;
    r) _ram=$OPTARG;;
    u) _usbo='-usbdevice disk:format=raw:';;
    w) _waiting=1;;
  esac; done
  shift $(($OPTIND-1))
  local _extra=$1
  [ -n "$1" ] && shift
  [ x"$1" = x-- ] && shift

  if [ -z "$(hvm_get_val $_name defined)" ]; then
    local _net=
    if [ "$_network" ]; then case "$_network" in
      local) _net=-l;;
      misc) _net=-m;;
      bridged:*) _net="-b ${_network#*:}";;
    esac; fi
    hvm_declare $_name $_net "$_ram" "$_cores"
  fi

  if hvm_make_transient; then
    _hvmd_launch_transient $_name "$@" ${_extra:+$_usbo"${hvm_tmp:-/tmp}/$_extra"}
  else
    _hvmd_launch_permanent $_name "$@" ${_extra:+$_usbo"${hvm_tmp:-/tmp}/$_extra"}
  fi || die launching $_name
}

hvm_save() {
  local _name=$1 _prepared=$2 _val=
  # Ensure the vm defined by hvm_def_$_name is in /etc/nbsvm, correctly.

  if [ -n "$_prepared" ]; then
    [ "$_prepared" != "$s_where"/hvm.stanza ] && cat "$_prepared" >"$s_where"/hvm.stanza
  else
    _hvmd_stanza $_name >"$s_where"/hvm.stanza
  fi

  if [ -n "$hvm_remote" ]; then
    ssh ${hvm_remote} ${hvm_root} cat /etc/nbsvm/${hvm_class:+$hvm_class-}$_name.vm >"$s_where"/hvm.old-vm.conf || true
    __save_conf() { ssh ${hvm_remote} $hvm_root tee /etc/nbsvm/${hvm_class:+$hvm_class-}$_name.vm <"$1" >/dev/null; }
  else
    ${hvm_root} cat /etc/nbsvm/${hvm_class:+$hvm_class-}$_name.vm >"$s_where"/hvm.old-vm.conf || true
    __save_conf() { $hvm_root cp "$1" /etc/nbsvm/${hvm_class:+$hvm_class-}$_name.vm; }
  fi

  if [ "$(cat "$s_where"/hvm.old-vm.conf)" = "$(cat "$s_where"/hvm.stanza)" ]; then
    : Definition unchanged, do nothing but return true.
  else
    __save_conf "$s_where"/hvm.stanza || die failed to save VM configuration
  fi
}

hvm_upload() {
  if [ -z "$2" -o x$2 = x'-' ]; then
    # TODO: hvm_root
    if [ -n "$hvm_remote" ]; then
      ssh $hvm_remote cat \> "\"${hvm_tmp:-/tmp}/$1\""
    else
      cat > "${hvm_tmp:-/tmp}/$1"
    fi
  else
    if [ -n "$hvm_remote" ]; then
      scp "$2" $hvm_remote:"${hvm_tmp:-/tmp}/$1"
    else
      cp "$2" "${hvm_tmp:-/tmp}/$1"
    fi
  fi || die uploading to "${hvm_remote:+$hvm_remote:}${hvm_tmp:-/tmp}/$1"
}

hvm_wait() {
  hvm_launch "$@" -- -no-reboot
  ${hvm_remote:+ssh -t $hvm_remote} $hvm_root ${nbsvm_class:-nbs}vm $1 monitor || die waiting for $1
}

# Implementation

_hvm_calc_args() {
  local _name=$1 _then=$2 _bridgeless=1 _val=
  shift 2

  _val=$(hvm_get_val $_name disc_count) _cnt=0
  while [ $_cnt -lt ${_val:-0} ]; do
    set -- "$@" -drive if=virtio,media=disk,file="(hvm_get_val $_name disc_${_cnt}_path)"
    _cnt=$(($_cnt + 1))
  done

  _val=$(hvm_get_val $_name cd_count) _cnt=0
  while [ $_cnt -lt ${_val:-0} ]; do
    set -- "$@" -drive if=virtio,media=cdrom,file="(hvm_get_val $_name cd_${_cnt}_path)"
    _cnt=$(($_cnt + 1))
  done

  _val=$(hvm_get_val $_name usb_count) _cnt=0
  while [ $_cnt -lt ${_val:-0} ]; do
    set -- "$@" -usbdevice disk:format=raw:"(hvm_get_val $_name cd_${_cnt}_path)"
    _cnt=$(($_cnt + 1))
  done

  _val=$(hvm_get_val $_name local_count) _cnt=0
  _net=$(($_net+${_val:-0}))
  while [ $_cnt -lt ${_val:-0} ]; do
    set -- "$@" -net nic -net user
    _cnt=$(($_cnt + 1))
  done

  _val=$(hvm_get_val $_name bridged_count) _cnt=0
  if [ ${_val:-0} -gt 1 ]; then
    LOG_error nbsvm only supports a single bridged NIC
    return 1
  fi
  _net=$(($_net+${_val:-0}))
  while [ $_cnt -lt ${_val:-0} ]; do
    set -- bridge="$(hvm_get_val $_name bridged_${_cnt}_settings)" "$@"
    _bridgeless=
    _cnt=$(($_cnt + 1))
  done

  _val=$(hvm_get_val $_name misc_count) _cnt=0
  _net=$(($_net+${_val:-0}))
  while [ $_cnt -lt ${_val:-0} ]; do
    set -- "$@" -net nic
    _cnt=$(($_cnt + 1))
  done

  if [ $_net -eq 0 ]; then set -- "$@" -net none; fi
  $_then ${_bridgeless:+network=-usb} "$@"
}

_hvmd_launch_permanent() {
  local _name=$1
  shift
  hvm_save $_name
  ${hvm_remote:+ssh -t $hvm_remote} $hvm_root nbsvm $_name start _ -daemonize "$@"
}

_hvmd_launch_transient() {
  local _name=$1
  shift
  local _val= _cnt= _net=0
  set -- nbsvm $_name start _ -daemonize "$@"
  # No templates on transient nbsvm
  _val=$(hvm_get_val $_name ram)
  [ -n "$_val" ] && set -- mem=$_val "$@"
  _val=$(hvm_get_val $_name cores)
  [ -n "$_val" ] && set -- smp=$_val "$@"

  _hvm_exec() { ${hvm_remote:+ssh -t $hvm_remote} $hvm_root env "$@"; }
  _hvm_calc_args $_name _hvm_exec "$@"
}

_hvmd_stanza() {
  local _name=$1 _val=

  # top
  # templates at the end
  # no autostart on nbsvm

  # ram
  _val=$(hvm_get_val $_name ram)
  [ -n "$_val" ] && echo "mem=$_val"

  _val=$(hvm_get_val $_name cores)
  [ -n "$_val" ] && echo "smp=$_val"

  # network & storage
  _hvm_do_args() {
    while [ $# != 0 -a "$1" != "${1%%=*}" -a "$(echo "${1%%=*}" | grep [^a-zA-Z0-9_])" = '' ]; do
      echo "$1"
      shift
    done
    echo 'args=(' "$@" ')'
  }
  _hvm_calc_args $_name _hvm_print_args

  # tail
  _val=$(hvm_get_val $_name template)
  [ -n "$_val" ] && echo ". /etc/nbsvm/\${class:+\$class-}$val.vm"
  echo '}'
}
