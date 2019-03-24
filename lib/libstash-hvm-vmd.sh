#!sh

_vmctl() { set -e; ${hvm_remote:+ssh $hvm_remote} doas vmctl "$@"; }

hvm_upload() {
  set -e
  if [ -z "$2" -o x$2 = x'-' ]; then
    if [ -n "$hvm_remote" ]; then
      ssh $hvm_remote cat \> "\"${hvm_dir:+$hvm_dir/}$1\""
    else
      cat > "${hvm_dir:+$hvm_dir/}$1"
    fi
  else
    if [ -n "$hvm_remote" ]; then
      scp "$2" $hvm_remote:"${hvm_dir+$hvm_dir/}$1"
    else
      cp "$2" "${hvm_dir+$hvm_dir/}$1"
    fi
  fi
}

hvm_clone() {
  set -e
  _id=$1 _ram=$2 _cpu=$3 _cd=$4 _usb=$5
  ...
#  ${ram:+mem="$ram"} ${cpu:+smp="$cpu"} \
#    nbsvm "$id" clone start             \
#    ${cd:+-cdrom "$cd" -boot d}         \
#    ${usb:+-usbdevice disk:format=raw:file}
}

hvm_create() {
  set -e
  _id=$1 _size=$2
  _vmctl create "qcow2:${hvm_dir:+$hvm_dir/}$_id.0" -s $_size
}

hvm_launch() {
  set -e
  _id=$1 _ram=$2 _cpu=$3 _cd=$4 _usb=$5
  if [ -n "$_cpu" -a "$_cpu" != 1 ]; then
    echo "SMP is not supported on vmd" >&2
    exit 1
  fi
  _vmctl start "$_id" -L ${_ram:+-m "$_ram"} \
    -d ${hvm_dir:+$hvm_dir/}$_id.0             \
    ${_cd:+-r "${hvm_dir:+$hvm_dir/}$_cd"}     \
    ${_usb:+-d "${hvm_dir:+$hvm_dir/}$_usb"}
}

hvm_wait() {
  set -e
  hvm_launch "$@"
  _vmctl wait "$1"
}
