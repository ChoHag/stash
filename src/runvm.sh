#!/bin/sh

set -e

: ${LIBSTASH:=$PWD} # /usr/local/share/stash
. "$LIBSTASH"/libstash.sh
. "$LIBSTASH"/lib/libstash-hvm.sh
APP=runvm

console=
while getopts hDcC:e:H:i:M:n: _opt; do case "$_opt" in
  \?) usage;;
  h) echo "Don't panic!"; usage;; # --help
  D) cli debug         true;;    # --debug

  c) cli console 1;;             # --console
  C) cli os_cpu   "$OPTARG";;    # --cpu
  e) cli envdir   "$OPTARG" ws;; # --environment
  H) cli hvm      "$OPTARG";;    # --hypervisor
  i) cli id       "$OPTARG";;    # --id
  M) cli os_ram   "$OPTARG";;    # --ram
  n) cli hostname "$OPTARG";;    # --hostname

  # -) --long-argument;;

esac; done
shift $(($OPTIND-1))

repo=$1

find_environment

[ -n "$hostname" ] || fail "No hostname"

_load_hvm $hvm

hvm_launch $env-$hostname${id:+-$id} $os_ram $os_cpu
