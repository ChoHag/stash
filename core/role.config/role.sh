#!sh

. "$LIBSTASH"/libstash-sht.sh

role_settings() {
  role method copy _config_copy
  role method line _config_line
  role method share _config_share
  role method take _config_take
  role method template _config_template
  role filetype replace-sht _config_replace_templated
  role filetype replace _config_replace
  role var files
  remember config_files
}

_config_replace() {
  set -e
  _config_copy -x $2 "/$(echo "${3#$1.}" | sed -r 's|_-\^?|/|g')"
}

_config_replace_templated() {
  set -e
  _config_template -X $2 "/$(echo "${3#$1.}" | sed -r 's|_-\^?|/|g')"
}

_config_share() {
  set +e
  local _dst=$1

  changed_config=
  if _what=$(paired "$config_files" "$_dst"); then
    if [ "$_what" = + ]; then
      # should delete from config_files
      [ -n "$running_role" ] && changed_config=prepend
      [ -n "$running_role" ] && prepend_pair $running_role+ "$_dst"
      return 0
    fi
    [ "${_what%[+-]}" != "$running_role" ] || fail role.${_what%[+-]} has already claimed "$_dst"
    [ "$_what" != "${_what%[+-]}" ] || fail "$_dst" is already exclusive to this role
    return 0
  fi

  changed_config=append
  append_pair config_files $running_role+ "$_dst"
}

_config_take() {
  set -e
  local _dst=$1 _shared=$2

  if _what=$(paired "$config_files" "$_dst"); then
    [ "$_what" != + ] || fail "$_dst" is already shared
    [ "${_what%[${_shared:+-}+]}" = $running_role ] || fail role.${_what%[-+]} has already shared "$_dst"
    return
  fi

  append_pair config_files $running_role${_shared:+-} "$_dst"
}

_config_copy() {
  set -e
  local _opt= _required= _src_gen= _tracked= _exclusive= _ex_shared=1
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts rmtxX _opt; do case "$_opt" in
    r) _required=1;; m) _src_gen=1;; t) _tracked=1;;
    x) _exclusive=take;; X) _exclusive=take _ex_shared= ;;
  esac; done
  shift $(($OPTIND-1))

  local _file=$1 _dst=$2 _mode=$3 _own=$4

  [ -n "$_tracked" ] || _config_${_exclusive:-share} "$_dst" ${_ex_shared:+-}

  if [ -z "$_src_gen" ]; then
    _esrc=$stash/env.$loaded_env/$_file
    _rsrc=$stash/role.$running_role/$_file
    [ ! -e "$_esrc" ] && local _src=$_rsrc || local _src=$_esrc

    LOG_info ... copy ${_tracked:+untracked} ${_exclusive:+exclusively} "$_dst"

    if [ ! -e "$_src" ]; then
      [ -n "$_required" ] || fail "role.$running_role/$_file" is missing
      return
    fi

    [ ! -f "$_src" ] && die_unsupported only files for config

  else
    local _src=$(mktemp)
    "$_file" > "$_src"
  fi

  config_changed=
  _force= ; [ -z "$_exclusive$_tracked" ] || _force=1
  if ! _maybe_copy ${_force:+-f} "$_src" "$_dst" "$_mode" "$_own"; then
    _r=$?
    rm -f "$_src_temp"
    case $_r in
    101) config_changed=copy;;
    102) config_changed=acl;;
    *) return $_r;;
    esac
  fi
  rm -f "$_src_temp"
}

_config_template() {
  set -e
  local OPTIND=1 OPTARG= # Bash needs this
  _opt= _pass= _how=
  while getopts re:txX _opt; do case "$_opt" in
    e) _how=$OPTARG;;
    [rtxX]) _pass="$_pass$_opt";;
  esac; done
  shift $(($OPTIND-1))
  _real_src=$1 _real_dst=$2
  shift # only shift 1
  _config_make_source() { ${how:-_sht_template} "$_real_src"; }
  LOG_info ... template "$_real_dst"
  _config_copy -m ${_pass:+-$_pass} _config_make_source "$@"
}

_config_line() {
  set -e
  local running_role= # Temporarily unset so that $config_files is
                      # updated in a way that this action does not
                      # take ownership of the file
  _ig=
  if [ "$1" = "-s" ]; then
    _ig='(ignored)'
    shift
  fi
  if [ -e "$2" ] && grep -qFx "$1" < "$2"; then
    LOG_info ... include into "$2": "$1" "(exists)"
    _config_share "$2"
  else
    LOG_info ... include into "$2": "$1" $_ig
    if ! _config_share "$2" && [ -z "$_ig" ]; then
      fail Cannot append to file with exclusive owner
    fi
    [ -z "$_ig" ] && echo "$1" >> "$2"
  fi
}
