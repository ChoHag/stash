#!sh

# Role methods to manage users and groups

# Still a work in progress but basically works.

role_settings() {
  role method group _users_group
  role method user  _users_user
}

_users_group() {
  set -ex
  _group=$1
  if ! _ent=$(getent group "$_group"); then # new group
    if on_openbsd; then group add \
      ${verbose:+-v}              \
      "$_group"
    fi
  else # group already exists
    die_unsupported Group $_group already exists
  fi
}

_users_user() {
  set -ex
  _home= _makehome=1
  # TODO: getopts
  while [ $# -ge 1 -a "$1" != "${1#-}" ]; do _opt=$1; shift
    case "$_opt" in
    -N) _makehome=;;
    -H|--home) _home=$1; shift;; --home=*) _home=${_opt#*=};;
    esac
  done
#  while getopts NH: _opt; do case "$_opt" in
#    N) _makehome=;;
#    H) _home=$OPTARG;;
#    \?) exit 1;;
#  esac; done
#  shift $OPTIND-1

  _user=$1
  _group=$2

  if ! _ent=$(getent passwd "$_user"); then # new user
    _group=${_group:-=uid}
    if on_openbsd; then user add ${verbose:+-v}  \
      ${_home:+-d "$_home"} ${_makehome:+-m}     \
      ${_group:+-g "$_group"}                    \
      "$_user"
    fi

  else # user already exists
    die_unsupported User $_user already exists
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
