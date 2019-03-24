#!sh

_load_hvm() {
  _hvm=$1
  [ -e "$LIBSTASH"/lib/libstash-hvm-$_hvm.sh ] || die_unsupported hypervisor $_hvm
  . "$LIBSTASH"/lib/libstash-hvm-$_hvm.sh
}
