#!sh

role_settings() {
  on_openbsd || die_unsupported
  role depends firewall network
  role var enabled
  role var nat
  role method enable-forwarding _router_enable
  role method enable-nat _router_enable_nat
  remember router_enabled router_nat
}

_router_enable() {
  local _ipv4= _ipv6=
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts 46 _opt; do case "$_opt" in
    4) _ipv4=1;; 6) _ipv6=1;;
  esac; done
  shift $(($OPTIND-1))
  [ -z "$ipv4" -a -z "$ipv6" ] && _ipv4=1
  if on_openbsd; then
    [ -n "$_ipv4" ] && stash config line net.inet.ip.forwarding=1 /etc/sysctl.conf
    [ -n "$_ipv6" ] && stash config line net.inet6.ip6.forwarding=1 /etc/sysctl.conf
  fi
  router_activated=${config_changed:+yes}
  role var enabled "${_ipv4:+4}${_ipv6:+${_ipv4:+ }6}"
}

_router_enable_nat() {
  if on_openbsd; then
    if [ "$1" = "--rfc1918" ]; then
      local _src="10/8 172.16/12 192.168/16"
    else
      local _src=$1
    fi
    stash config line -s "internet = \"{ 0/0 }\"" /etc/pf.conf
    stash config line -s "match out on $interface from { $_src } to \$internet nat-to $2" /etc/pf.conf
  fi
}

role_apply() {
  if [ -n "$router_enabled" ]; then _router_enable; fi
}
