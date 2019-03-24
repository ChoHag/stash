#!sh

# Everything to do with loading and applying roles

# Take of which variables are local in this file and which are
# not. Behind the scenes roles do a lot of fucking around with sh's
# global state.

_role_import() {
  # TODO: Consider using copy_function to save loaded methods and not
  # have to keep recompiling.
  [ -d "$stash/role.$running_role" ] || return 1
  role_apply() { :; }
  role_settings() { :; }
  . "$stash/role.$running_role/role.sh"; _r=$?
  eval "$(echo "role_depends_$role_depends=" | tr - _)"
  return $_r
}

role_depends() { eval "$(echo "echo \$role_depends_$role_depends" | tr - _)"; }

_role_load() {
  set -e
  local running_role=${1:?No role}
  for _role in $loaded_roles; do [ "$running_role" = $_role ] && return 0; done
  LOG_notice "Loading role $running_role"
  # The first time a role is loaded, clear out its namespace
  for _v in $(set | grep "$(echo "^${running_role}_.*=" | tr - _)" | cut -d= -f1); do unset $_v; done
  _role_import
  role_settings
  # order is important
  append_var loaded_roles "$running_role"
}

_role_settings() {
  set -e
  for _role; do
    local running_role=$_role
    _role_import
    role_settings
  done
}

_role_do_method() {
  set -e
  _role=$1 _method=$2
  shift; shift
  for _can in $s_can_method; do
    if [ "${_can%=*}" = "$_role:$_method" ]; then
      "${_can#*=}" "$@"
      return $?
    fi
  done
  return 1
}

_role_each_file() {
  set -e
  local _filetype=$1 _role=$2 _method=$3
  for _file in "$stash/role.$running_role/$_filetype".*; do
    [ "$_file" != "$stash/role.$running_role/$_filetype.*" ] || break
    _name=${_file#$stash/role.$running_role/$_filetype.}
    [ -e env.$loaded_env/"$_name" ] && _file=env.$loaded_env/"$_name"
    "$_method" "$_filetype" "${_file#$stash/role.$running_role/}" "$_name"
  done
}

_role_finish() {
  set -e
  for _each_role in $loaded_roles; do
    LOG_notice "Applying $_each_role"
    for _spec in $s_can_file; do
      LOG_debug "($_spec?)"
      local running_role=$_each_role
      _by_role=${_spec%%:*} _action=${_spec#*:}
      _type=${_action%=*} _function=${_action##*=}
      _role_each_file "$_type" "$_by_role" "$_function"
    done
    local running_role=$_each_role
    _role_import "$_each_role"
    role_apply
  done
}

#

role() {
  set -e
  local _how=$1
  shift
  case "$_how" in
  depends)
    append_var role_depends_$running_role "$@"
    for _role in "$@"; do _role_load $_role; done
    ;;
  do)       _role_do_method "$@";;
  filetype) role_filetype "$@";;
  method)   role_method "$@";;
  var)      rolevar "$@";;
  esac
}

# TODO: rename:

# This might be a bit silly...
rolevar() { eval "$(echo "eval \": \\\\\${\${running_role}_\$1:=$2}\"" | tr - _)"; }

role_method() {
  _method=$1 _function=${2:-_${running_role}_$1}
  LOG_info "Handling method: $running_role $_method"
  if ! paired -q "$s_can_method" "$_method=$_function"; then
    append_var s_can_method "$running_role:$_method=$_function"
  fi
}

role_filetype() {
  _type=$1 _function=${2:-_${running_role}_$1}
  LOG_info "Handling file type: $_type by $_role"
  if ! paired -q "$s_can_file" "$_type=$_function"; then
    append_var s_can_file "$running_role:$_type=$_function"
  fi
}
