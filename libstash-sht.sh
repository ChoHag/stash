#!sh

sht_include() {
  local _src=$(stash filename "$1")

  _proc=$(mktemp)
  (
    echo '_sht_do_template() {'
    echo '  set -e'${debug:+x}
    echo '  sed s/^EOF// <<EOF'
    sed 's/^EOF/&&/' < "$_src"
    echo 'EOF'
    echo '}'
  ) >> "$_proc"
  . "$_proc"
  rm -f "$_proc"
  (_sht_do_template) || die template "$_src"
}

_sht_template() {
  local _src=$1
  exec 3>&1
  [ -n "$2" ] && exec >>"$2"

  sht_include "$_src"
  _r=$?
  
  exec 1>&3 3>&-
  return $_r
}
