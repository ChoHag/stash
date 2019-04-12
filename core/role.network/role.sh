#!sh
# Role methods to do networking

role_settings() {
  role method ifconfig network_ifconfig
  role var early
  eval role var gateway_ipv4 "\$subnet_$(mysubnet)_ipv4_gateway"
  eval role var gateway_ipv6 "\$subnet_$(mysubnet)_ipv6_gateway"
  eval role var nameserver "\$subnet_$(mysubnet)_nameserver"
  role var devices # ro
  remember network_devices
}

role_apply() {
  if on_firsttime; then
    find /etc -type f | xargs grep -l changeme | while read f; do
      LOG_info ... host name in $f
      [ -n "$hostname" ] && printf '/changemehost/s//%s/\nw\n' $hostname | ed -s $f 2>/dev/null
      [ -n "$domain"   ] && printf '/changemedomain/s//%s/\nw\n' $domain | ed -s $f 2>/dev/null
    done
    if on_openbsd; then
      hostname $(cat /etc/myname) || LOG_warning cannot set hostname live
    elif on_linux; then
      hostname $(cat /etc/hostname) || LOG_warning cannot set hostname live
    fi
  fi

  local _changed= _early=
  if [ -n "$network_early" ]; then
    for _early in $network_early; do
      network_early "$_early"
      : ${_changed:=$network_changed}
    done
  fi

  if on_openbsd; then
    [ -n "$network_gateway_ipv4" ] && stash config line "$network_gateway_ipv4" /etc/mygate
    [ -n "$network_gateway_ipv6" ] && stash config line "$network_gateway_ipv6" /etc/mygate
    [ -n "$network_nameserver" ] \
      && stash config set-line nameserver "nameserver $network_nameserver" /etc/resolv.conf
  fi

  if [ -n "$_changed" ]; then
    if on_openbsd; then sh /etc/netstart || die bringing up network
    else die undefined; fi
  fi
}

network_early() {
  local oIFS=$IFS IFS=:
  set -o noglob
  set -- $1
  set +o noglob
  IFS=$oIFS
  network_ifconfig "$@"
}

network_ifconfig() {
  local _model=$1 _dev=$2 _src= _dst=
  if on_openbsd; then
    _src=sht.hostname.$_model _dst=/etc/hostname.$_dev
  elif on_centos; then
    _src=sht.ifcfg.$_model _dst=/etc/somewhere/$_dev.conf
  elif on_deb; then
    _src=sht.interfaces.$_model _dst=/etc/network/interfaces.d/$_dev
  fi
  LOG_info ... network device "$_dev"
  if _what=$(paired "$network_devices" "$_dev"); then
    if [ "$_what" != "$running_role" ]; then
      die $running_role has already configured "$_dev"
    fi
    # Continue as normal in case the supplement has changed it but
    # don't append to $network_devices again.
  else
    append_pair network_devices $running_role "$_dev"
  fi
  case "$_model" in
  simple) stash config template "$_src" "$_dst";;
  *) die undefined;;
  esac
  _r=$?
  network_changed=${config_changed:+yes}
  return $_r
}
