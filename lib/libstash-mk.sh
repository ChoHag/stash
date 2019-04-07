#!sh

_hook_append() { cat >> "$s_where"/installer-post-hook; }
_hook_append_pre() { cat >> "$s_where"/installer-pre-hook; }
_hook_append_firsttime() {
  exec 3>&1 >>"$s_where"/installer-post-hook
  echo "cat >> \$_top/etc/rc.firsttime <<'EOF'"
  cat
  echo EOF
  exec >&3 3>&-
}

prepare_hook() {
  set -e
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi
  _top=/mnt
  if want_deb; then _top=/target; fi
  mkdir -p "$s_where"/payload/stash
  echo '#!/bin/sh' > "$s_where"/installer-pre-hook
  echo '#!/bin/sh' > "$s_where"/installer-post-hook
  echo _top=$_top | _hook_append # To reduce quoting pain
  if [ -n "$debug" ]; then
    _hook_append_pre <<'HOOK'
mkdir /tmp/hookfiles
cp /payload /tmp/hookfiles
cp /mkautoiso-prehook.sh /tmp/hookfiles
cp /mkautoiso-posthook.sh /tmp/hookfiles
HOOK
    echo 'cp $_top/etc/rc.firsttime /tmp/hookfiles/rc.firsttime.before' | _hook_append
  fi

  _hook_append < "$LIBSTASH"/lib/post-hook.head.sh

  for v in debug environment hostname domain id role sign proxy proxy_runtime; do
    eval echo $v=\"\$$v\";
  done | _hook_append
}

prepare_fixup() {
  set -e
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi

  # First some os-specific customisation & defaults
  if want_openbsd; then
    if [ -n "$debug" ]; then
      echo 'cp /auto_install.conf /tmp/hookfiles ||:' | _hook_append
      echo 'cp /disklabel.template /tmp/hookfiles ||:' | _hook_append
    fi
    # 0 fstab
    _count=$(get_fslayout | read-layout -count)
    _disc=0
    while [ $_disc -lt $_count ]; do
      get_fslayout | read-layout openbsd $_disc | while read _line; do
        case "$_line" in
        \#*) echo "$_disc ${_line### }" >&2;;
        *)   echo "$_line";;
        esac
      done >> "$s_where"/payload/disklabel.$_disc 2>> "$s_where"/payload/format-options
      _disc=$(($disc+1))
    done

    # 2 packages
    _pkg=
    for _p in $os_packages; do
      if [ "$_p" != "${_p#[-+]}" ]; then
        append_var _pkg "$_p"
      else
        append_var os_sets "$_p"
      fi
    done
    if [ -n "$os_packages" -a -z "$_pkg" -a -z "$os_sets" ]; then os_sets=' '; fi
    echo "os_packages='$_pkg'" | _hook_append

    _hook_append < "$LIBSTASH"/lib/post-hook.openbsd.sh
    [ -z "$_clone" ] || _hook_append_firsttime < "$LIBSTASH"/lib/post-hook.openbsd-clone.sh

  elif want_centos; then
    # if clone and lvm, unique uuid
    if [ -n "$debug" ]; then echo 'cp /ks.cfg /tmp/hookfiles ||:' | _hook_append_pre; fi
    if [ -n "$_clone" ]; then echo yum -y upgrade | _hook_append_firsttime; fi
    _hook_append < "$LIBSTASH"/lib/post-hook.centos.sh

  elif want_deb; then
    # $packages +ssh to preseed
    # update, upgrade, install to firsttime
    # if clone and lvm, unique uuid in firsttime
    # if clone, ssh keys in firsttime
    if [ -n "$debug" ]; then echo 'cp /preseed.cfg /tmp/hookfiles ||:' | _hook_append_pre; fi
    echo 'inroot() { in-target "$@"; }' | _hook_append
    cp "$LIBSTASH"/lib/rc.local.firsttime "$s_where"/payload/rc.local.firsttime
    if [ -n "$_clone" ]; then
      echo 'apt-get update && apt-get -y dist-upgrade' | _hook_append_firsttime
    fi
    _hook_append < "$LIBSTASH"/lib/post-hook.deb.sh
  fi

  # Hook debug hooks
  if [ -n "$debug" ]; then
    _hook_append <<EOF
cp $_top/etc/rc.firsttime /tmp/hookfiles/rc.firsttime.after
tar -C /tmp -cf $_top/hookfiles.tar hookfiles
EOF
    LOG_debug Installer hooks are available in "$s_where" on the local system and /hookfiles.tar on the target
  fi

  _hook_append_firsttime <<EOF
# (no LOG_* in here)
echo "Autorun..." >&2
if auto_run; then
  auto_halt
  echo "Success. Rebooting." >&2
else
  echo "Failed (\$?)." >&2
fi
EOF

  # Final os-specific customisation
  if want_openbsd; then echo halt -p | _hook_append; fi
}

build_userdata() {
  set -e
  # This function might be piped into build_iso or boot_2 so could bypass -e;
  # error-check explicitly.
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi
  _stash() {
    mkstash ${debug:+-D} -r $role   \
      ${s_wherein:+-w "$s_wherein"} \
      ${envdir:+-e $envdir}         \
      -n $hostname ${id:+-i $id}    \
      "$@"
  }
  if [ "$stash_from" = iso -o -z "$sign" ]; then
    LOG_warning Stashing without a signature
    _stash -o- "$@" || fail mkstash
  elif [ "$sign" = signify ]; then
    # Verify with signify -Vz < signed > payload
    _stash -o "$s_where"/unsigned "$@" || fail mkstash
    signify -Snz -s "$stash_key" -m "$s_where"/unsigned -x "$s_where"/signed || fail sign
    cat "$s_where"/signed
  else
    ...
  fi
}

build_iso() {
  set -e
  # This function might be piped into boot_1 so could bypass -e;
  # error-check explicitly.
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi
  _userdata=$1
  set -- "$iso_source"
  if want_openbsd && [ -n "os_sets" ]; then
    set -- -p "$os_sets" "$@"
  elif [ -n "$os_packages" ]; then
    set -- -p "$os_packages" "$@"
  fi

  if [ "$stash_from" = iso ]; then
    [ -z "$_userdata" ] && fail userdata
    cat "$_userdata" > "$s_where"/payload/stash.tgz
  elif [ "$stash_from" != script-only ]; then
    mkstash ${debug:+-D} \
      ${s_wherein:+-w "$s_wherein"} \
      ${envdir:+-e $envdir}         \
      ${stash_from:+-f $stash_from} \
      -o "$s_where"/payload/stash.tgz -O
  fi

  ( cd "$s_where"/payload; find . -type f | tar -cf- -I- ) \
    > "$s_where"/installer-payload || fail tar payload

  _name=${hostname:-${fqdn%%.*}}.${domain:-${fqdn#*.}}

  mkautoiso ${debug:+-D} -o- -I "$iso_source"  \
    ${s_wherein:+-w "$s_wherein"}              \
    -P "$os_platform" ${hostname:+-F "$_name"} \
    ${iso_rootkey:+-K "$iso_rootkey"}          \
    ${iso_rootpw:+-R "$iso_rootpw"}            \
    ${os_fslayout:+-l "$os_fslayout"}          \
    ${os_upstream:+-r "$os_upstream"}          \
    ${os_version:+-V "$os_version"}            \
    ${proxy:+-x "$proxy"}                      \
    ${proxy_runtime:+-X "$proxy_runtime"}      \
    -B "$s_where"/installer-pre-hook           \
    -A "$s_where"/installer-post-hook          \
    -Y "$s_where"/installer-payload            \
    "$@" || fail mkautoiso
}

boot_1() { # reads stdin
  set -e
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi
  _auto_iso=$1; shift
  _vmname=$env-${1:-$hostname${id:+-$id}}
  hvm_create $_vmname $os_size || fail hvm_create # ignores -e
  hvm_upload auto-reformat-$_vmname.iso \
    < "$_auto_iso" || fail hvm_upload # probably ignores -e too
  hvm_wait   $_vmname "$os_ram" "$os_cpu" auto-reformat-$_vmname.iso
  # pre-hook, install, post-hook
}

boot_2() {
  set -e
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi
  if [ "$stash_from" != iso ]; then _userdata=$1; shift; fi
  _vmname=$env-${1:-$hostname${id:+-$id}}
  if [ "$stash_from" = iso ]; then
    hvm_wait $_vmname $ram $cpu
  else
    _stashname=stash-$_vmname
    case "$stash_from" in
    usb*)
      _stashname=$_stashname.disc
      case "$stash_from" in
      usb:*) hvm_upload $_stashname <${stash_from#usb:};;
      usb)
        root "$(which mkstashfs)" <"$_userdata" >"$s_where"/usb.img
        hvm_upload $_stashname <"$s_where"/usb.img
        ;;
      *) ...;;
      esac
      hvm_wait $_vmname "$os_ram" "$os_cpu" '' $_stashname
      ;;
    http:*|https:*) ... ;;
    pxe)...;;
    *);;
    esac
  fi
  hvm_launch $_vmname "$os_ram" "$os_cpu"
}
