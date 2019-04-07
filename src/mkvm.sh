#!/bin/sh

set -e

: ${LIBSTASH:=$PWD} # /usr/local/share/stash
. "$LIBSTASH"/libstash.sh
. "$LIBSTASH"/lib/libstash-hvm.sh
. "$LIBSTASH"/lib/libstash-mk.sh
APP=mkvm

stash_from=iso _transient_here=

while getopts hD+:C:d:e:H:i:I:K:l:M:n:p:P:r:R:s:S:Tu:V:w:x:X: _opt; do case "$_opt" in
  \?) usage;;
  h) echo "Don't panic!"; usage;;    # --help
  D) cli debug         true;;        # --debug

  +) cli "${OPTARG%%=*}" "${OPTARG#*=}";; # --set
  # TODO: replace some of these with -+ (iso/os):
  C) cli os_cpu       "$OPTARG";;    # --cpu
  d) cli domain       "$OPTARG";;    # --domain
  e) cli envdir       "$OPTARG" ws;; # --environment
  H) cli hvm          "$OPTARG";;    # --hypervisor
  i) cli id           "$OPTARG";;    # --id
  I) cli iso_source   "$OPTARG";;    # --iso
  l) cli os_fslayout  "$OPTARG";;    # --layout
  K) cli iso_rootkey  "$OPTARG" ws;; # --root-key
  M) cli os_ram       "$OPTARG";;    # --ram
  n) cli hostname     "$OPTARG";;    # --hostname
  p) cli os_packages  "$OPTARG" ws;; # --packages
  P) cli os_platform  "$OPTARG";;    # --platform
  r) cli role         "$OPTARG";;    # --role
  R) cli iso_rootpw   "$OPTARG" ws;; # --password
  s) cli sign         "$OPTARG";;    # --sign
  S) cli os_size      "$OPTARG";;    # --size
  T) _transient_here=1;;
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

[ -n "$role" ] || fail "No role"
[ -n "$hostname" ] || fail "No hostname"
[ -n "$os_size" ] || fail "No size"

if [ "$iso_source" = - ]; then iso_source= ; fi

if [ "$hvm" = aws ]; then
  echo "Cannot run mkvm for aws; use mkclone & mkinstance" >&2
  exit 1
fi
_load_hvm $hvm $_transient_here

_mkwhere

_call() { set -e; LOG_debug Calling $1; "$@"; }

# TODO: Don't use fifos; they're weird
_call prepare_hook
_call prepare_fixup
chmkdir 0700 : "$s_where"/fifo
mkfifo "$s_where"/fifo/userdata
mkfifo "$s_where"/fifo/iso
_call build_userdata "$@" > "$s_where"/fifo/userdata &
wait_ud() { wait $_ud || fail build_userdata; wait_ud() { :; }; }
atexit wait_ud
_ud=$!
_call build_iso "$s_where"/fifo/userdata > "$s_where"/fifo/iso &
_iso=$!
wait_iso() { wait $_iso || fail build_iso; wait_iso() { :; }; }
atexit wait_iso
_call boot_1 "$s_where"/fifo/iso || fail boot_1
_call boot_2
