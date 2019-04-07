#!/bin/sh

set -e

: ${LIBSTASH:=$PWD} # /usr/local/share/stash
. "$LIBSTASH"/libstash.sh
. "$LIBSTASH"/lib/libstash-hvm.sh
. "$LIBSTASH"/lib/libstash-mk.sh
APP=mkclone

_clonename=clone
while getopts hD+:d:e:f:H:I:K:l:n:p:P:R:s:S:u:V:w:x:X: _opt; do case "$_opt" in
  \?) usage;;
  h) echo "Don't panic!"; usage;; # --help
  D) cli debug         true;;        # --debug

  +) cli "${OPTARG%%=*}" "${OPTARG#*=}";; # --set
  d) cli domain       "$OPTARG";;    # --domain
  e) cli envdir       "$OPTARG" ws;; # --environment
  f) cli stash_from   "$OPTARG" ws;; # --stash-from
  H) cli hvm          "$OPTARG";;    # --hypervisor
  I) cli iso_source   "$OPTARG";;    # --iso
  K) cli iso_rootkey  "$OPTARG" ws;; # --root-key
  l) cli os_fslayout  "$OPTARG";;    # --layout
  n) cli _clonename   "$OPTARG";;    # --clone-name
  p) cli os_packages  "$OPTARG" ws;; # --packages
  P) cli os_platform  "$OPTARG";;    # --platform
  R) cli iso_rootpw   "$OPTARG" ws;; # --password
  s) cli sign         "$OPTARG";;    # --sign
  S) cli os_size      "$OPTARG";;    # --size
  u) cli os_upstream  "$OPTARG";;    # --upstream
  V) cli os_version   "$OPTARG";;    # --version
  w) cli s_wherein    "$OPTARG" ws;; # --workdir
  x) cli proxy        "$OPTARG";;    # --proxy
  X) cli proxy_system "$OPTARG";;    # --proxy-system

  # -) --long-argument;;

esac; done
shift $(($OPTIND-1))

repo=$1

find_environment

[ -n "$os_size" ] || fail "No size"

if [ "$iso_source" = - ]; then iso_source= ; fi

_load_hvm $hvm transient

_mkwhere

_call() { set -e; LOG_info Calling $1; "$@"; }

# TODO: Don't use fifos; they're weird
_call prepare_hook --clone
_call prepare_fixup --clone

_call build_iso > "$s_where"/iso
_call boot_1 "$s_where"/iso "$_clonename" || fail boot_1
