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
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi
  _top=/mnt
  if want_deb; then _top=/target; fi
  mkdir -p "$s_where"/payload/stash
  echo '#!/bin/sh' > "$s_where"/installer-pre-hook
  echo '#!/bin/sh' > "$s_where"/installer-post-hook
  if want_deb; then
    echo "sed s/^EOFEOF/EOF/ >/mkautoiso-partmouse.sh <<'EOF'"
    sed 's/^EOF/&&/' <"$LIBSTASH"/lib/partmouse.sh
    echo EOF
    echo chmod 755 /mkautoiso-partmouse.sh
  fi | _hook_append_pre
  echo _top=$_top | _hook_append # To reduce quoting pain
  if [ -n "$debug" ]; then
    _hook_append_pre <<'HOOK'
mkdir /tmp/hookfiles
cp /payload /tmp/hookfiles
cp /mkautoiso-prehook.sh /tmp/hookfiles
cp /mkautoiso-posthook.sh /tmp/hookfiles
HOOK
    if want_deb; then
      echo cp /mkautoiso-partmouse.sh /tmp/hookfiles | _hook_append_pre
    fi
    echo 'cp $_top/etc/rc.firsttime /tmp/hookfiles/rc.firsttime.before' | _hook_append
  fi

  _hook_append < "$LIBSTASH"/lib/post-hook.head.sh

  for v in debug environment hostname domain id role sign proxy proxy_runtime; do
    eval echo $v=\"\$$v\";
  done | _hook_append
}

prepare_fixup() {
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
      [ -s "$s_where"/payload/disklabel.$_disc ] || die parsing disklabel "$os_fslayout"
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
    if [ -n "$debug" ]; then echo 'cp /ks.cfg /tmp/hookfiles' | _hook_append_pre; fi
    if [ -n "$_clone" ]; then echo yum -y upgrade | _hook_append_firsttime; fi
    _hook_append < "$LIBSTASH"/lib/post-hook.centos.sh

  elif want_deb; then
    # $packages +ssh to preseed
    # update, upgrade, install to firsttime
    # if clone and lvm, unique uuid in firsttime
    # if clone, ssh keys in firsttime
    if [ -n "$debug" ]; then echo 'cp /preseed.cfg /tmp/hookfiles' | _hook_append_pre; fi
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
  if want_openbsd; then
    if [ "$hvm" = nbsvm ]; then echo reboot; else echo halt -p; fi | _hook_append
  fi
}

build_userdata() {
  # This function might be piped into build_iso or boot_2 so could bypass -e;
  # error-check explicitly.
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi
  _stash() {
    runcli mkstash ${debug:+-D}     \
      ${s_wherein:+-w "$s_wherein"} \
      ${envdir:+-e $envdir}         \
      -n $hostname ${id:+-i $id}    \
      -r $role "$@" || die mkstash userdata
  }
  if [ "$stash_from" = iso -o -z "$sign" ]; then
    _stash -s '' -S "$sign" -o- "$@"
  else
    _stash -s "$sign" -o- "$@"
  fi
}

build_iso() {
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
    [ -n "$_userdata" ] || die no userdata for one-shot iso
    cat "$_userdata" > "$s_where"/payload/stash.tgz
  elif [ "$stash_from" != script-only ]; then
    runcli mkstash ${debug:+-D}     \
      ${s_wherein:+-w "$s_wherein"} \
      ${envdir:+-e $envdir}         \
      ${stash_from:+-f $stash_from} \
      -s '' -S "$sign" -o "$s_where"/payload/stash.tgz -O || die mkstash core
  fi

  ( cd "$s_where"/payload; find . -type f | tar -cf- -I- ) \
    > "$s_where"/installer-payload || die building payload archive

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
    "$@" || die mkautoiso
}

boot_1() { # reads stdin
  if [ "$1" = --clone ]; then _clone=1; shift; else _clone= ; fi
  _auto_iso=$1; shift
  _vmname=$env-${1:-$hostname${id:+-$id}}
  hvm_create $_vmname $os_size || fail hvm_create # ignores -e
  hvm_upload auto-reformat-$_vmname.iso \
    <"$_auto_iso" || fail hvm_upload # probably ignores -e too
  if [ -n "$os_definition" ]; then
    _toeval=
    while read -r _line; do
      _toeval=$(echo "$_toeval"; echo "$_line")
    done <"$os_definition"
    eval "hvm_declare \\$_toeval"
    hvm_wait $_vmname
  else
    hvm_wait $_vmname ${os_ram:+-r"$os_ram"} ${os_cpu:+-c"$os_cpu"} ${os_network:+-n"$os_network"} auto-reformat-$_vmname.iso
  fi
  # pre-hook, install, post-hook
}

boot_2() {
  local _clone= _stashname= _vmname= _toeval=
  if [ "$1" = --clone ]; then _clone=1; shift; fi
  if [ "$stash_from" != iso ]; then _userdata=$1; shift; fi
  _vmname=$env-${1:-$hostname${id:+-$id}}
  if [ -n "$os_definition" ]; then
    set -- $_vmname
    if [ -z "$(hvm_get_val $_vmname defined)" ]; then
      while read -r _line; do
        _toeval=$(echo "$_toeval"; echo "$_line")
      done <"$os_definition"
      eval "hvm_declare \\$_toeval"
    fi
  else
    set -- $_vmname          \
      ${os_ram:+-r"$os_ram"} \
      ${os_cpu:+-c"$os_cpu"} \
      ${os_network:+-n"$os_network"}
  fi

  if [ "$stash_from" != iso ]; then
    if [ -n "$os_clone_from" ]; then hvm_clone $_vmname "$os_clone_from" || die clone; fi
    _stashname=stash-$_vmname _waitopt=
    case "$stash_from" in
    cd)
      _waitopt=$_stashname.iso
      mkdir "$s_where"/stashcd
      mkhybrid -aro "$s_where"/cd.img /stash.tgz="$_userdata"
      hvm_upload $_stashname.iso <"$s_where"/cd.img
      ;;
    usb:*)
      _waitopt=-u\ $_stashname.fs
      hvm_upload $_stashname.fs <${stash_from#usb:};;
    usb)
      _waitopt=-u\ $_stashname.fs
      root "$(which mkstashfs)" <"$_userdata" >"$s_where"/usb.img || die mkstashfs
      hvm_upload $_stashname.fs <"$s_where"/usb.img
      ;;
    http:*|https:*) die undefined;;
    pxe) die undefined;;
    *);;
    esac
  fi
  hvm_wait "$@" $_waitopt
  hvm_launch "$@"
}
