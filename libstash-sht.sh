#!sh

sht_include() {
  set -e
  if [ "$1" != "${1#env/}" ]; then
    local _src=$stash/env.$loaded_env/${1#env/}
  elif [ "$1" = "${1#env.}" ]; then
    local _src=$stash/role.$running_role/$1
  else
    local _src=$stash/$1
  fi

  _proc=$(mktemp)
  (
    set -e
    echo '_sht_do_template() {'
    echo '  sed s/^EOF// <<EOF'
    sed 's/^EOF/&&/' < "$_src"
    echo 'EOF'
    echo '}'
  ) >> "$_proc"
  . "$_proc"
  rm -f "$_proc"
  (_sht_do_template)
}

_sht_template() {
  set -e
  local _src=$1
  exec 3>&1
  [ -n "$2" ] && exec >>"$2"

  sht_include "${_src#$stash/role.$running_role/}" # will put it back
  _r=$?
  
  exec 1>&3 3>&-
  return $_r
}
