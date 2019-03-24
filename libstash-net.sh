#!sh

myname() { echo ${hostname%.$domain}; }

myname_var() { myname | tr - _; }

mycidr4() {
  if [ -z "$1" ]; then eval "_subnet=\${server_$(myname_var)_subnet%% *}"; else _subnet=$1; fi
  if eval [ \"\$subnet_${_subnet}\" = dynamic ]; then echo dynamic; return
  else eval echo \$subnet_${_subnet}_ipv4; fi
}

mycidr6() {
  if [ -z "$1" ]; then eval "_subnet=\${server_$(myname_var)_subnet%% *}"; else _subnet=$1; fi
  if eval [ \"\$subnet_${_subnet}\" = dynamic ]; then echo dynamic; return
  else eval echo \$subnet_${_subnet}_ipv6; fi
}

myipv4() {
  if [ -z "$1" ]; then eval "_subnet=\${server_$(myname_var)_subnet%% *}"; else _subnet=$1; fi
  if eval [ \"\$subnet_${_subnet}\" = dynamic ]; then echo dynamic
  else eval echo \$server_$(myname_var)_ipv4_$_subnet; fi
}

myipv6() {
  if [ -z "$1" ]; then eval "_subnet=\${server_$(myname_var)_subnet%% *}"; else _subnet=$1; fi
  if eval [ \"\$subnet_${_subnet}\" = dynamic ]; then echo dynamic
  else eval echo \$server_$(myname_var)_ipv6_$_subnet; fi
}

mynm4() {
  _cidr=$(mycidr4 "$@")
  [ -n "$_cidr" ] || return
  _nm=${_cidr#*/}
  # Number of args to shift, 255..255, first non-255 byte, zeroes
  set -- $(( 4 - ($_nm / 8) )) 255 255 255 255 $(( (255 << (8 - ($_nm % 8))) & 255 )) 0 0 0
  [ $1 -gt 0 ] && shift $(($1+1)) || shift
  echo ${1-0}.${2-0}.${3-0}.${4-0}
}

mynm6() {
  _cidr=$(mycidr6 "$@")
  [ -n "$_cidr" ] || return
  echo ${_cidr#*/}
}
