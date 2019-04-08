#!/bin/sh

set -e

: ${LIBSTASH:=$PWD} # /usr/local/share/stash
. "$LIBSTASH"/libstash.sh
. "$LIBSTASH"/lib/libstash-hvm.sh
. "$LIBSTASH"/lib/libstash-mk.sh
APP=mkinstance

sign=none _transient_here=

while getopts hD+:c:C:e:f:F:H:i:I:M:n:N:r:s:Tw: _opt; do case "$_opt" in
  \?) usage;;
  h) echo "Don't panic!"; usage;;    # --help
  D) cli debug         true;;        # --debug

  +) cli "${OPTARG%%=*}" "${OPTARG#*=}";; # --set
  c) cli os_clone_from "$OPTARG";;    # --clone-from
  C) cli os_cpu        "$OPTARG";;    # --cpu
  e) cli envdir        "$OPTARG" ws;; # --environment
  f) cli stash_from    "$OPTARG" ws;; # --stash-from
  F) cli os_definition "$OPTARG" ws;; # --[machine-]definition
  H) cli hvm           "$OPTARG";;    # --hypervisor
  i) cli id            "$OPTARG";;    # --id
  M) cli os_ram        "$OPTARG";;    # --ram
  N) cli os_network    "$OPTARG";;    # --network
  n) cli hostname      "$OPTARG";;    # --hostname
  r) cli role          "$OPTARG";;    # --role
  s) cli sign          "$OPTARG";;    # --sign
  T) _transient_here=1;;
  w) cli s_wherein     "$OPTARG" ws;; # --workdir

  # -) --long-argument;;

esac; done
shift $(($OPTIND-1))

repo=$1

find_environment

[ -n "$role" ] || fail "No role"
[ -n "$hostname" ] || fail "No hostname"
[ -n "$stash_from" ] || fail "No stash source"
[ "$sign" != none ] || fail "No signature method"

_load_hvm $hvm $_transient_here

_mkwhere

_call() { set -e; LOG_info Calling $1; "$@"; }

# TODO: This fucks up mkautoiso because of lack of uname (!?)
# /mkautoiso-posthook.sh: /mnt/root/stash/libstash.sh[344]: uname: not found
# stash[73286] error Unsupported platform: unknown
if on_openbsd; then
  root() { [ $(id -u) = 0 ] && "$@" || doas "$@"; }
elif on_linux; then
  root() { [ $(id -u) = 0 ] && "$@" || sudo "$@"; }
fi

_call build_userdata --clone "$@" > "$s_where"/userdata
_call boot_2 --clone "$s_where"/userdata
