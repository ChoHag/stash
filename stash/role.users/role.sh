#!sh

# Role methods to manage users and groups

# Still a work in progress but basically works.

role_settings() {
  role method group _users_group
  role method user  _users_user
}

_users_group() {
  set -e
  _group=$1
  LOG_info ... group $_group
  if ! _ent=$(getent group "$_group"); then # new group
    if on_openbsd; then group add \
      ${verbose:+-v}              \
      "$_group"
    fi
  else # group already exists
    local _gname= _gpwd= _ggid= _gmembers=
    fn() {
      local IFS=:
      set -o noglob
      set -- $_ent
      set +o noglob
      _gname=$1 _gpwd=$2 _ggid=$3 _gmembers=$4
    }
    fn
    : No options, nothing to change
  fi
}

_users_user() {
  set -e
  local _home= _makehome=1
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts NH: _opt; do case "$_opt" in
    -N) _makehome=;;
    -H) _home=$OPTARG;;
  esac; done
  shift $(($OPTIND-1))
  local _user=$1 _group=$2

  LOG_info ... user $_user
  if ! _ent=$(getent passwd "$_user"); then # new user
    _group=${_group:-=uid}
    if on_openbsd; then user add ${verbose:+-v}  \
      ${_home:+-d "$_home"} ${_makehome:+-m}     \
      ${_group:+-g "$_group"}                    \
      "$_user"
    fi

  else # user already exists
    local _pname= _ppwd= _puid= _pgid= _pgecos= _phome= _pshell=
    fn() {
      local IFS=:
      set -o noglob
      set -- $_ent
      set +o noglob
      _pname=$1 _ppwd=$2 _puid=$3 _pgid=$4 _pgecos=$5 _phome=$6 _pshell=$7
    }
    fn
    if [ -n "$_home" -a "$_home" != "$_phome" ]; then
      die_unsupported HOME has changed for $_user
    fi
    if [ -n "$_group" -a "$_group" != "$_pgid" ]; then # TODO: could also be group name
      die_unsupported GID has changed for $_user
    fi
  fi
}

_users_group_file() {
  _prefix=$1
  shift;
  for _file; do
    _read_file_vars "$_prefix" "$_file" \
                    groupname
    _users_group "$groupname"
  done
  ...
}
