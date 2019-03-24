#!sh

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
  _id=$1
  _ram=$2 # opt
  _cpu=$3 # opt
  _cd=$4 # opt
  _usb=$5 # opt
  ${hvm_remote:+ssh -t $hvm_remote} ${_ram:+mem="$_ram"} ${_cpu:+smp="$_cpu"} \
    ${nbsvm_class:-nbs}vm "$_id" clone start _ -daemonize                \
    ${_cd:+-_cdrom "${hvm_dir+$hvm_dir/}$_cd" -boot d}                       \
    ${_usb:+-_usbdevice disk:format=raw:"${hvm_dir+$hvm_dir/}$_usb"}
}

hvm_create() {
  set -e
  _id=$1
  _size=$2
  # TODO: other nbsvm settings (esp. class)
  ${hvm_remote:+ssh -t $hvm_remote} drive_size=$_size ${nbsvm_class:-nbs}vm "$_id" newimg
}

hvm_launch() {
  set -e
  _id=$1
  _ram=$2 # opt
  _cpu=$3 # opt
  _cd=$4 # opt
  _usb=$5 # opt
  if [ -n "$_ram" -a "${_ram}" = "${_ram%[0-9]}" ]; then
    mul=${_ram##*[0-9]}; _ram=${_ram%?}
    case $mul in
    [tT])((_ram*=1048576));; [gG])((_ram*=1024));; [mM]);;
    *) fail Unknown multiplier;;
    esac
  fi
  ${hvm_remote:+ssh -t $hvm_remote} ${_ram:+mem="$_ram"} ${_cpu:+smp="$_cpu"} \
    ${nbsvm_class:-nbs}vm "$_id" start _ -daemonize -no-reboot              \
    ${_cd:+-cdrom "${hvm_dir+$hvm_dir/}$_cd" -boot d}                         \
    ${_usb:+-_usbdevice disk:format=raw:"${hvm_dir+$hvm_dir/}$_usb"}
}

hvm_wait() {
  set -e
  hvm_launch "$@"
  ${hvm_remote:+ssh -t $hvm_remote} ${nbsvm_class:-nbs}vm "$1" serial
}
