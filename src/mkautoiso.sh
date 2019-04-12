#!/bin/sh

usage() {
  echo '?'
  exit 1
}

: ${LIBSTASH:=$PWD} # /usr/local/share/stash
. "$LIBSTASH"/libstash.sh
. "$LIBSTASH"/lib/libstash-mk.sh
APP=mkautoiso

while getopts hDA:B:F:I:K:l:o:p:P:R:r:V:w:x:X:Y: _opt; do case "$_opt" in
  \?) usage;;
  h) echo "Don't panic!"; usage;; # --help
  D) cli debug         true;;         # --debug

  A) cli iso_post_hook "$OPTARG" ws;; # --post-hook
  B) cli iso_pre_hook  "$OPTARG" ws;; # --pre-hook
  F) cli fqdn          "$OPTARG";;    # --fqdn
  I) cli iso_source    "$OPTARG";;    # --iso
  K) cli iso_rootkey   "$OPTARG" ws;; # --root-key
  l) cli os_fslayout   "$OPTARG";;    # --layout
  o) cli outfile       "$OPTARG" ws;; # --out
  p) cli os_packages   "$OPTARG" ws;; # --packages
  P) cli os_platform   "$OPTARG";;    # --platform
  r) cli os_upstream   "$OPTARG";;    # --remote
  R) cli iso_rootpw    "$OPTARG" ws;; # --password
  V) cli os_version    "$OPTARG";;    # --version
  w) cli s_wherein     "$OPTARG" ws;; # --workdir
  x) cli proxy         "$OPTARG";;    # --proxy
  X) cli proxy_runtime "$OPTARG";;    # --proxy-system
  Y) cli iso_payload   "$OPTARG" ws;; # --data

  # -) --long-argument;;

esac; done
shift $(($OPTIND-1))

set_cli
if [ "$iso_source" = - ]; then iso_source= ; fi
if [ "$outfile" = - ]; then outfile= ; fi
: ${proxy_runtime:=$proxy}
if [ "$proxy_runtime" = none ]; then proxy_runtime= ; fi
: ${hostname:=${fqdn%%.*}}
[ "$fqdn" = "${fqdn#*.}" ] || : ${domain:=${fqdn#*.}}

_mkwhere

iso_fn=${outfile:-"$s_where"/auto-reformat--"${iso_source##*/}"}
iso_mount=$s_where/mnt # MUST be set before sourcing libraries
mkdir "$iso_mount"

load_ramdisc() { echo none; }
save_ramdisc() { :; }

. "$LIBSTASH"/iso/libiso.build-$(on).sh
. "$LIBSTASH"/iso/libiso.target-$os_platform.sh

_call() { LOG_debug Calling $1; "$@"; }

_mp=$(_call mount_iso "$iso_source")
_call sync_iso
_call umount_iso $_mp
_rd=$(_call mount_ramdisc)
_call fiddle_serial
_call fiddle_autoinstall # inc. layout, halt
_call fiddle_hooks
_call umount_ramdisc $_rd
_call mkiso

if [ -z "$outfile" ]; then cat "$iso_fn"; fi
LOG_debug Prepared ISO and ramdisc are in "$s_where"
