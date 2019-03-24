#!/bin/sh

# hint: restash and push:
#   restash -n name ~/src/repo | ssh root@100.64.5.3 tar -C stash -xzvf-

set -e

: ${LIBSTASH:=$PWD} # /usr/local/share/stash
. "$LIBSTASH"/libstash.sh
APP=restash

while getopts hDe:i:n:o:w: _opt; do case "$_opt" in
  \?) usage;;
  h) echo "Don't panic!"; usage;; # --help
  D) cli debug         true;;     # --debug

  e) cli envdir    "$OPTARG" ws;; # --environment
  i) cli id        "$OPTARG";;    # --id
  n) cli hostname  "$OPTARG";;    # --hostname
  o) cli outfile   "$OPTARG" ws;; # --out
  w) cli s_wherein "$OPTARG" ws;; # --workdir

  # -) --long-argument;;

esac; done
shift $(($OPTIND-1))

repo=$1

find_environment

[ -n "$hostname" ] || fail "No hostname"

mkstash ${debug:+-D}            \
  ${s_wherein:+-w "$s_wherein"} \
  ${envdir:+-e$envdir}          \
  -n $hostname ${id:+-i$id}     \
  ${outfile:+-o$outfile}        \
  "$@"
