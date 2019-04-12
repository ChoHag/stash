#!/bin/sh

set -e

: ${LIBSTASH:=$PWD} # /usr/local/share/stash
. "$LIBSTASH"/libstash.sh
. "$LIBSTASH"/lib/libstash-mk.sh
APP=mkstash

_compression=9 _withcore=true _verify=
while getopts hD0123456789+:e:f:i:n:o:Or:s:S:w: _opt; do case "$_opt" in
  \?) usage;;
  h) echo "Don't panic!"; usage;; # --help
  D) cli debug         true;;      # --debug
  [0-9]) _compression=$_opt;;

  +) cli_extra      "$OPTARG";;    # --set
  e) cli envdir     "$OPTARG" ws;; # --environment
  f) cli stash_from "$OPTARG" ws;; # --stash-from
  i) cli id         "$OPTARG";;    # --id
  n) cli hostname   "$OPTARG";;    # --hostname
  o) cli outfile    "$OPTARG" ws;; # --out
  O) cli _withcore  '';;
  r) cli role       "$OPTARG";;    # --role
  s) cli sign       "$OPTARG";;    # --sign
  S) cli _verify    "$OPTARG";;    # --sign
  w) cli s_wherein  "$OPTARG" ws;; # --workdir

  # -) --long-argument;;

esac; done
shift $(($OPTIND-1))

repo=$1

find_environment

if [ "$outfile" = - ]; then outfile= ; fi

_mkwhere
mkdir -p "$s_where"/stash

# Library
( cd "$LIBSTASH"; find . -maxdepth 1 -type f -name lib\* ) \
  | tar -C "$LIBSTASH" -cf- -I- | tar -C "$s_where"/stash -xf-

_completed=
got() { for _m in $_completed; do [ "$_m" = "$1" ] && return 0; done; return 1; }

install_stash() {
  # TODO: This has become a mess.
  _src=${1%/}
  _name=${_src##*/}
  _dst=$s_where/stash/$_name
  if [ ! -e "$_dst" ]; then
    # Simple case
    LOG_debug Stashing "$_name" from "${_src%/$_name}"
    tar -C "${_src%/*}" -cf- "${_src##*/}" | tar -C "$s_where"/stash -xf-
    [ -e "$_dst/complete" ] && rm "$_dst/complete" && append_var _completed "$_name"
  else
    if [ -f "$_dst" -a -d "$_src" ]; then fail Cannot replace file with directory
    elif [ -f "$_src" ]; then fail Cannot replace anything with file
    else
      for _from in "$_src"/.* "$_src"/*; do
        case "$_from" in
        *~|*.bak|*/\#*|"${envdir%/}/${_from##*/}") continue;;
        "$_src/."|"$_src/.."|"$_src/.*"|"$_src/*"|*~) continue;;
        "$_src/complete") append_var _completed "$_name";;
        */env.${_name#env.}/env.sh|*/role.${_name#role.}/role.sh)
          # Surprisingly, this doesn't work right (role.sh).
          LOG_debug Stashing .../"${_from#$_src/}" from "$_src"
          if [ -e "$_dst"/${_from##*/} ]; then
            _tail=$(mktemp -p "$_dst" ${_from##*/}.XXXXXX)
            mv "$_dst"/${_from##*/} "$_tail"
            cp "$_from" "$_dst"
            echo "# End of ${_from%/${_from##*/}}" >> "$_dst"/${_from##*/}
            cat "$_tail" >> "$_dst"/${_from##*/}
            rm "$_tail"
          else
            cp "$_from" "$_dst"
          fi
          ;;
        *)
          LOG_debug Stashing .../"${_from#$_src/}" from "$_src"
          tar -C "${_src}" -cf- "${_from#$_src/}" | tar -C "$_dst" -xf-
          ;;
        esac
      done
    fi
  fi
}

# TODO: role.supplement is special; look for it even in -O mode

# Roles, environments and run.sh; run.sh is a bit hackish.
[ -e "$envdir" ] && install_stash "$envdir"
[ -e "$LIBSTASH"/run.sh ] || cp src/run.sh "$s_where"/stash/run # dev
for _dir in "$@" ${_withcore:+"$LIBSTASH"} "$LIBSTASH"/lib; do
  _all=; [ "$_dir" = "${_dir#$LIBSTASH}" ] && _all=1
  if [ "$_dir" != "${_dir#$LIBSTASH}" ]; then
    for _file in "$_dir"/role.* "$_dir"/env.* "$_dir"/run.sh "$_dir"/org.sh; do
      [ -e "$_file" ] || continue
      _name=${_file##*/}
      contains "$_completed" "$_name" && continue
      install_stash "$_file"
    done
  else
    for _file in "$_dir"/*; do
      [ -e "$_file" ] || continue
      _name=${_file##*/}
      contains "$_completed" "$_name" && continue
      install_stash "$_file"
    done
  fi

  if [ -e "$s_where"/stash/run.sh ]; then
    if [ -e "$s_where"/stash/run ]; then rm "$s_where"/stash/run.sh
    else mv "$s_where"/stash/run.sh "$s_where"/stash/run; fi
  fi
done
[ -e "$s_where"/stash/run ] || cp "$LIBSTASH"/run.sh "$s_where"/stash/run
chmod 755 "$s_where"/stash/run

(
  if [ -n "$role" ]; then
    echo role=$role${env:+/$env}
    echo fqdn=${hostname:-$role}${id:+-$id}.$domain # TODO: allow override
  else
    echo environment=$env # default_?
  fi
  echo sign=${_verify:-$sign}
  echo stash_from=$stash_from
) >> "$s_where"/stash/id

sign() {
  case $sign in
  '')
    LOG_warning Stashing without a signature
    cat
    ;;
  signify)
    local _exe=signify; if on_deb; then _exe=signify-openbsd; fi
    if want_openbsd; then
      cat > "$s_where"/unsigned
      # Verify with signify -Vz <signed >payload
      $_exe -Snz -s "$stash_key" -m "$s_where"/unsigned -x-
    else
      # Verify with zverify verify -Vq -t stash -m- -x -- <s >p
      zsign $_exe -Sn -s "$stash_key" -m- -x-
    fi
    ;;
  gpg) zsign gpg -abs;; # Verify with zverify gpg --verify -- - <s >p
  *) die_unsupported sign $sign;;
  esac || die sign
}

cd "$s_where"/stash
[ -n "$outfile" ] && exec > "$outfile"
find . -mindepth 1 -type f -a \! \( -name \*~ -o -name \*.bak -o -name \#\* \) \
  | tar -I- -cf - | gzip -c$_compression | sign
LOG_debug Stashed contents are available in "$s_where"/stash
