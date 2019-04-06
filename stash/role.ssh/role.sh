#!sh

role_settings() {
  role method pubkey _ssh_public_key
  role var ca_address
  role var ca_hosts
  role var ca_users
}

role_apply() {
  set -e
  if [ -n "$ssh_ca_address" ]; then
    for _kt in ed25519; do
      local _cert=/etc/ssh/ssh_host_${_kt}_cert.pub
      if [ ! -s $_cert ]; then
        LOG_info ... ssh certificate $_cert
        sh $stash/role.ssh/request-host-certificate-ssh "$ssh_ca_hosts@$ssh_ca_address" $_kt
        _r=$? # For some reason not caught by -e
        [ $_r -eq 0 ] || return $_r
      fi
      stash config line -p "HostCertificate $_cert" /etc/ssh/sshd_config
    done
  fi
}

_ssh_public_key() {
  set -e
  local _ca= _system= _line= _list= _opt= _user=
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts cs _opt; do case "$_opt" in
    c) _ca=1;; s) _system=1;;
  esac; done
  shift $(($OPTIND-1))
  if [ -z "$_system" ]; then _user=$1; shift; fi
  local _file= _match=$2
  _file=$(stash filename "$1")
  [ -n "$_file" ] || fail Cannot find ssh public key "$1"

  _line="${_ca:+@cert-authority }${_match:-?} $(tr -d \\n < "$_file")"
  _list=${_system:+/etc/ssh/ssh_known_hosts}
  : ${_list:=$(getent passwd $_user | cut -d: -f6)}
  stash config line "$_line" "$_list"
  # Check permission of user files here? Must be overridable (or/and off by default)
}
