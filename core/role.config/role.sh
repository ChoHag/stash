#!sh

role_settings() {
  role method copy _config_copy
  role method line _config_line
  role method set-line config_set_line
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

config_set_line() {
  # Like _config_line, which this starts as copy pasta of, except the
  # first argument is the line's prefix which, if matched in the file,
  # is removed first.

  local _prepend=
  if [ "$1" = -p ]; then _prepend=1; shift; fi
  local running_role= # Temporarily unset so that $config_files is
                      # updated in a way that this action does not
                      # take ownership of the file
  local _ig=
  if [ "$1" = "-s" ]; then
    _ig='(ignored)'
    shift
  fi
  if [ -e "$3" ] && grep -qFx "$2" < "$3"; then
    LOG_info ... include into "$3": "$1" "(exists)"
    _config_share "$3"
  else
    LOG_info ... include solo in "$3": "$2" $_ig
    if ! _config_share "$3" && [ -z "$_ig" ]; then
      fail Cannot include in file with exclusive owner
    fi
    if [ -z "$_ig$_prepend" ]; then
      echo "g/^$1/d\n\$a\n$2\n.\nw" | ed -s "$3"
    elif [ -z "$_ig" ]; then
      echo "g/^$1/d\n1a\n$2\n.\nw" | ed -s "$3"
    fi
  fi
}

_config_share() {
  set +e
  local _dst=$1 _what=

  changed_config=
  if _what=$(paired "$config_files" "$_dst"); then
    if [ "$_what" = + ]; then
      # should delete from config_files
      [ -n "$running_role" ] && changed_config=prepend
      [ -n "$running_role" ] && prepend_pair $running_role+ "$_dst"
      return 0
    fi
    [ "${_what%[+-]}" = "$running_role" ] || fail role.${_what%[+-]} has already claimed "$_dst"
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
    [ -z "$_shared" -o "${_what%-}" = $running_role ] || fail this role has already shared "$_dst"
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

  local _file=$1 _dst=$2 _mode=$3 _own=$4 _src=

  [ -n "$_tracked" ] || _config_${_exclusive:-share} "$_dst" ${_ex_shared:+-}

  if [ -z "$_src_gen" ]; then
    _src=$(stash filename "$_file") || true
    if [ $? != 0 ]; then
      [ -n "$_required" ] || fail "role.$running_role/$_file" is missing
      return
    fi
    LOG_info ... copy ${_tracked:+untracked} ${_exclusive:+exclusively} "$_dst"
    [ ! -f "$_src" ] && die_unsupported only files for config

  else
    _src=$(mktemp)
    "$_file" > "$_src"
  fi

  config_changed=
  local _force= ; [ -z "$_exclusive$_tracked" ] || _force=1
  _r=0
  _maybe_copy ${_force:+-f} "$_src" "$_dst" "$_mode" "$_own" || _r=$?
  rm -f "$_src_temp"
  case $_r in
  101) config_changed=copy;;
  102) config_changed=acl;;
  *) return $_r;;
  esac
  rm -f "$_src_temp"
}

_config_template() {
  set -e
  local OPTIND=1 OPTARG= # Bash needs this
  local _opt= _pass= _how=
  while getopts re:txX _opt; do case "$_opt" in
    e) _how=$OPTARG;;
    [rtxX]) _pass="$_pass$_opt";;
  esac; done
  shift $(($OPTIND-1))
  local _real_src=$1 _real_dst=$2
  shift # only shift 1
  _config_make_source() { ${how:-_sht_template} "$_real_src"; }
  LOG_info ... template "$_real_dst"
  _config_copy -mx ${_pass:+-$_pass} _config_make_source "$@"
}

_config_line() {
  set -e
  local _ig= _only= _prepend= _section=
  local OPTIND=1 OPTARG= # Bash needs this
  while getopts i:ops _opt; do case "$_opt" in
    i) _section=$OPTARG;;
    o) _only=1;;
    p) _prepend=1;;
    s) _ig='(ignored)';;
  esac; done
  shift $(($OPTIND-1))
  local _line=$1 _file=$2 _ig=
  local running_role= # Temporarily unset so that $config_files is
                      # updated in a way that this action does not
                      # take ownership of the file

  if [ -n "$_only" ]; then
    if [ ! -e "$_file" -o "$(cat "$_file" | tr -d \\n)" != "$_line" ]; then
      echo "$_line" > "$_file"
      # owner/mode? config_changed?
    fi
    return
  fi

  if [ -e "$_file" ] && grep -qFx "$_line" <"$_file"; then
    LOG_info ... include into "$_file": "$_line" "(exists)"
    _config_share "$_file"

  else
    LOG_info ... include into "$_file"${_section:+" ($_section)"}: "$_line" $_ig
    if ! _config_share "$_file" && [ -z "$_ig" ]; then
      fail Cannot update file with exclusive owner
    fi
    # Easy ones out of the way first
    if [ -z "$_ig$_prepend$_section" ]; then
      echo "$_line" >> "$_file"
    elif [ -z "$_ig$_section" ]; then
      printf '1i\n%s\n.\nw\n' "$_line" | ed -s "$_file"

    elif [ -n "$_section" ]; then
      if grep -qFx "$_section" <"$_file"; then # existing section:
        local _safe=$(echo "$_section" | sed 's|[\^.[$()|*+?{\\]|\\&|g')
        printf '/^%s$/a\n%s\n.\nw\n' "$_safe" "$_line"     | ed -s "$_file"
      elif [ -n "$_prepend" ]; then  # insert at top of file:
        printf '1i\n%s\n%s\n\n.\nw\n' "$_section" "$_line" | ed -s "$_file"
      else                           # at bottom:
        printf '$a\n\n%s\n%s\n.\nw\n' "$_section" "$_line" | ed -s "$_file"
      fi
    fi
  fi
}
