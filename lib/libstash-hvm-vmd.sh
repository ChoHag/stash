#!sh

hvm_create() {
  local _name=$1 _size=$2 _id=${3:-0}
  _hvmd_vmctl create "qcow2:${hvm_dir:+$hvm_dir/}$_name.$_id" -s $_size
}

hvm_launch() {
  set +e
  local _name=$1 _def= _trans=; shift
  [ -z "$(hvm_get_val $_name defined)" ]; _def=$?
  ! hvm_make_transient; _trans=$?
  if [ $_def = 1 -a \( \( "$1" != "${1#-}" -a "$1" != -u \) -o \( "$2" != "${2#-}" \) \) ]; then
    echo Unexpected arguments to hvm_launch >&2
    return 1
  fi

  local _opt= _ram= _usbo=-r _usbf=cd
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts c:r:u _opt; do case "$_opt" in
  c)
    echo "SMP is not supported on vmd" >&2
    return 1
    ;;
  r) _ram=$OPTARG;;
  u) _usbo=-d _usbf=disc;; # attach extra disc as usb (vmd: block) instead of cd
  esac; done
  shift $(($OPTIND-1))
  local _extra=$1

  case $_def$_trans in
  00)
    hvm_declare $_name -ld ${hvm_dir:+$hvm_dir/}$_name.0 $_ram
    _hvmd_launch_declared $_name $_usbf ${_extra:+"${hvm_dir:+$hvm_dir/}tmp/$_extra"}
    ;;
  01)
    _hvmd_vmctl start $_name -L ${_ram:+-m "$_ram"} \
      -d ${hvm_dir:+$hvm_dir/}$_name.0             \
      ${_extra:+$_usbo "${hvm_dir:+$hvm_dir/}tmp/$_extra"}
    ;;
  10)
    _hvmd_launch_declared $_name $_usbf ${_extra:+"${hvm_dir:+$hvm_dir/}tmp/$_extra"};;
  11)
    _hvmd_launch_transient $_name;;
  esac
}

hvm_save() {
  local _name=$1 _prepared=$2 _val=
  # Ensure the vm defined by hvm_def_$_name is in vm.conf, correctly,
  # and reload otherwise

  # First, create the actual definition
  if [ -n "$_prepared" ]; then
    [ "$_prepared" != "$s_where"/hvm.stanza ] && cat "$_prepared" >"$s_where"/hvm.stanza
  else
    _hvmd_stanza $_name >"$s_where"/hvm.stanza
  fi

  if [ -n "$hvm_remote" ]; then
    ssh ${hvm_remote} ${hvm_root} cat /etc/vm.conf >"$s_where"/hvm.old-vm.conf
    __save_conf() { ssh ${hvm_remote} ${hvm_root} tee /etc/vm.conf <"$1" >/dev/null; _hvmd_vmctl reload; }
  else
    ${hvm_root} cat /etc/vm.conf >"$s_where"/hvm.old-vm.conf
    __save_conf() { ${hvm_root} cp "$1" /etc/vm.conf; _hvmd_vmctl reload; }
  fi

  # Now do the dance to, if there's a same-$_name vm defined replace it
  # with stanza, otherwise append. If vm.conf was changed, reload vmd.
  local _rx="^vm[[:space:]]+(instance[[:space:]]+\"[^\"]*\"[[:space:]]+)?\"$_name\"[[:space:]]*\\{\$"
  if ! grep -qE "$_rx" <"$s_where"/hvm.old-vm.conf; then
    ( cat "$s_where"/hvm.stanza && echo ) >>"$s_where"/hvm.old-vm.conf
    __save_conf "$s_where"/hvm.old-vm.conf

  else
    sed -nr "/$_rx/,/^}$/p" <"$s_where"/hvm.old-vm.conf >"$s_where"/hvm.previous
    if [ "$(cat "$s_where"/hvm.previous)" = "$(cat "$s_where"/hvm.stanza)" ]; then
      : Definition unchanged, do nothing but return true.

    else
      local _state=before _line=
      # Prepare the replacement vm.conf
      ${hvm_remote:+ssh $hvm_remote} ${hvm_root} cat /etc/vm.conf | while IFS= read -r _line; do
        case $_state in
        before)  if echo "$_line" | grep -qE "$_rx";          then _state=in;      cat "$s_where"/hvm.stanza; echo
                 else echo "$_line"; fi;;
        in)      if [ "$_line" = \} ];                        then _state=between; fi;;
        between) if ! echo "$_line" | grep -q ^[[:space:]]*$; then _state=after;   echo "$_line"; fi;;
        after)   echo "$_line";;
        esac
      done >"$s_where"/hvm.new-vm.conf

      if ! diff -q "$s_where"/hvm.new-vm.conf "$s_where"/hvm.old-vm.conf >/dev/null 2>&1; then
        __save_conf "$s_where"/hvm.new-vm.conf
      fi
    fi # definition has changed
  fi # definition isn't present
}

hvm_upload() {
  local _name=$1 _src=$2
  if [ -z "$_src" -o x$_src = x'-' ]; then
    if [ -n "$hvm_remote" ]; then
      ssh -C $hvm_remote cat \> "\"${hvm_dir:+$hvm_dir/}tmp/$_name\""
    else
      cat > "${hvm_dir:+$hvm_dir/}tmp/$_name"
    fi
  else
    if [ -n "$hvm_remote" ]; then
      scp -C "$_src" $hvm_remote:"${hvm_dir+$hvm_dir/}tmp/$_name"
    else
      cp "$_src" "${hvm_dir+$hvm_dir/}tmp/$_name"
    fi
  fi
}

hvm_wait() {
  set -e
  hvm_launch "$@"
  _hvmd_vmctl wait "$1"
}

# Implementation

_hvmd_launch_declared() {
  local _name=$1 _usbf=$2 _extra=$3
  if [ -n "$_extra" ]; then
    hvm_get_all $_name >"$s_where"/hvm.stanza-saved
    hvm_attach_$_usbf $_name "$_extra"
  fi
  hvm_save $_name
  [ -n "$(hvm_get_val $_name auto)" ] || _hvmd_vmctl start $_name
  if [ -n "$_extra" ]; then
    eval "$(cat "$s_where"/hvm.stanza-saved)"
    hvm_save $_name
  fi
}

_hvmd_launch_transient() {
  local _name=$1
  local _val= _cnt= _net=0
  _val=$(hvm_get_val $_name template)
  [ -n "$_val" ] && set -- "$@" -t "$_val"
  _val=$(hvm_get_val $_name ram)
  [ -n "$_val" ] && set -- "$@" -m "$_val"
  # No cores on vmd
  _val=$(hvm_get_val $_name disc_count) _cnt=0
  while [ $_cnt -lt ${_max:-0} ]; do
    set -- "$@" -d "$(hvm_get_val $_name disc_${_cnt}_path)";
    _cnt=$(($_cnt + 1))
  done
  _val=$(hvm_get_val $_name cd_count) _cnt=0
  while [ $_cnt -lt ${_max:-0} ]; do
    set -- "$@" -r "$(hvm_get_val $_name cd_${_cnt}_path)";
    _cnt=$(($_cnt + 1))
  done
  _val=$(hvm_get_val $_name usb_count) _cnt=0
  while [ $_cnt -lt ${_max:-0} ]; do # usb as regular disc until vmd gets usb support
    set -- "$@" -d "$(hvm_get_val $_name usb_${_cnt}_path)";
    _cnt=$(($_cnt + 1))
  done
  _val=$(hvm_get_val $_name local_count) _cnt=0
  _net=$(($_net+${_val:-0}))
  while [ $_cnt -lt ${_max:-0} ]; do
    set -- "$@" -L
    _cnt=$(($_cnt + 1))
  done
  _val=$(hvm_get_val $_name bridged_count) _cnt=0
  _net=$(($_net+${_val:-0}))
  while [ $_cnt -lt ${_max:-0} ]; do
    set -- "$@" -n "$(hvm_get_val $_name bridged_${_cnt}_settings)";
    _cnt=$(($_cnt + 1))
  done
  _val=$(hvm_get_val $_name misc_count)
  if [ ${_val:-0} -gt 0 ]; then
    set -- -i $(($_net + $_val))
  fi
  _hvmd_vmctl start "$@"
}

_hvmd_output_block() {
  local _name=$1 _type=$2 _term=${3:-disk} _max=$(hvm_get_val $1 ${2}_count) _cnt=0
  while [ $_cnt -lt ${_max:-0} ]; do
    _val=$(hvm_get_val $_name ${_type}_${_cnt}_path)
    local _fmt=$(hvm_get_val $_name ${_type}_${_cnt}_format)
    echo "  ${_term} \"$_val\"${_fmt:+ format \"$_fmt\"}"
    _cnt=$(($_cnt+1))
  done
}

_hvmd_output_network() {
  local _name=$1 _type=$2 _max=$(hvm_get_val $1 ${2}_count) _cnt=0
  while [ $_cnt -lt ${_max:-0} ]; do
    _val=$(hvm_get_val $_name ${_type}_${_cnt}_settings)
    case $_type in
    local)   echo "  local interface";;
    bridged) echo "  interface { switch \"$_val\" }";;
    misc)    echo "  interface";;
    esac
    _cnt=$(($_cnt+1))
  done
}

_hvmd_stanza() {
  local _name=$1 _val=

  # top
  _val=$(hvm_get_val $_name template)
  echo "vm ${_val:+\"$_val\" instance }\"$_name\" {"
  [ -n "$(hvm_get_val $_name auto)" ] && echo "  enable" || echo "  disable"

  # ram
  _val=$(hvm_get_val $_name ram)
  [ -n "$_val" ] && echo "  memory $_val"

  # no cores on vmd

  # networks
  _hvmd_output_network $_name local
  _hvmd_output_network $_name bridged
  _hvmd_output_network $_name misc

  # storage
  _hvmd_output_block $_name disc
  _hvmd_output_block $_name cd cdrom
  _hvmd_output_block $_name usb disk

  # tail
  echo '}'
}

_hvmd_vmctl() { ${hvm_remote:+ssh $hvm_remote} ${hvm_root} vmctl "$@"; }
