#!sh

# It may be desirable to provide a default value for an environment
# setting in the repo but this will not be indicated here because it
# applies to everything.

# Lower-case x is something not expected on the command line but
# permitted/likely.

# X marks variables which are expected in
#                           Internal
#                           :Repo
#                           ::Environment
#                           :::Command-line
# Defaults; only env is this special
default_environment=dev  # [.X..] ## was default_environment
# Some variables in the root namespace
APP=                     # [X...] Name for logging ## was APP
debug=                   # [...X] ## was debug
cli=                     # [X...] command-line parsing
domain=                  # [..XX] dns ## was domain
env=                     # [..X.] Environment reported by loaded settings.sh ## was env
envdir=                  # [...X] Environment given on the command-line, might be $env or .../env.$env ## was envdir
environment=             # [X...] Environment given to run.sh ## was environment
finish=                  # [X...] run time ## was finish
fqdn=                    # [X...] dns ## was fqdn
hostname=                # [...X] dns ## was hostname
id=                      # [...X] unique within env ## was id
loaded_env=              # [X...] The name of the environment which was loaded ## was loaded_env
loaded_roles=            # [X...] The names of roles which have been loaded, in dependency order * ## was loaded_roles
repo=                    # [...X] The primary repository; usually the first non-option argument
role=                    # [...X] Server's primary role ## was role
role_depends=            # [X...] also role_depends(); may conflict? ## was role_depends
running_role=            # [X...] [R ] The name of the role which is currently loading or loading ## was running_role
start=                   # [X...] run time ## was start
outfile=                 # [...X] ? ## was outfile
proxy=                   # [..XX] for install time ## was proxy_install
proxy_runtime=           # [.XXx] for runtime ## was proxy_system
secdir=                  # [...x] Alternative secrets directory for signing keys
sign=                    # [..Xx] how to sign ## was sign

# Dunno what these are
extra_cli=               # [X...] unused ## was extra_cli
hvm=                     # [..Xx] This server's hypervisor ## was hvm
hvm_dir=                 # [..Xx] image path ## was hvm_dir
hvm_remote=              # [..Xx] address ## was hvm_remote

# Stash 'public' variables
: ${stash:=/root/stash}  # [X...] Top of extracted stash tree; this is the only lower-case variable to come from the environment ## was : ${stash:
stash_dirty=             # [X...] [R?] A list of cleanup functions to call ## was stash_dirty
stash_trap=              # [X...] [R?] A list of cleanup functions to call at death ## was stash_trap
stash_key=               # [X...] path to environment signing key
stash_pubkey=            # [X...] in-repo path to environment signing public key
stash_from=              # [X.Xx] Where to get a stash payload from ## was stashfrom
stashed_var=             # [X...] [R?] A list of variables to record ## was stashed_var

# Stash internal variables
os_cpu=                  # [..XX] qty ## was cpu
os_packages=             # [..XX] ? ## was packages
os_platform=             # [..XX] Target os ## was platform
os_ram=                  # [..XX] qty, mb or qualified ## was ram
os_sets=                 # [..XX] ## was openbsd_sets
os_size=                 # [..XX] qty, mb or qualified ## was size
s_can_file=              # [X...] Collected by -roles: filetypes roles can install ## was can_file
s_can_method=            # [X...] Collected by -roles: methods roles can perform ## was can_roles
s_on=                    # [X...] The current os
s_where=/tmp/nowhere     # [X...] will be deleted at end ## was where
s_wherein=               # [...X] Working area; only ever mktemp in here, never delete it ## was wherein

# Variables used by libiso.sh
iso_fn=                  # [X...] Filename to use for mkiso in case of stdout
iso_mount=/mnt           # [X...] ? ## was mount
iso_payload=             # [X..X] ? ## was payload
iso_post_hook=           # [X..X] ? ## was post_hook
iso_pre_hook=            # [X..X] ? ## was pre_hook
iso_rootkey=             # [.XXX]
iso_rootpw=              # [...X] pre-crypted ## was rootpw ## Not crypted on openbsd; use key
iso_source=              # [...X] upstream ## was iso
os_fslayout=             # [..XX] fs layout ## was layout
os_upstream=             # [..XX] upstream repo ## was remote
os_version=              # [..XX] target os version ## was version

. "$LIBSTASH"/libstash-env.sh
. "$LIBSTASH"/libstash-role.sh
. "$LIBSTASH"/libstash-net.sh

_has_logger= ; logger </dev/null 2>&0 || _has_logger=1
_make_logger() {
  _level=$1 _std=$2
  _maybedebug=
  [ "$_level" = debug ] && _maybedebug='[ -n "$debug" ] || return 0;'
  if [ -z "$_has_logger" ]; then
    eval "LOG_$_level() {
      $_maybedebug
      logger ${_std:+-s} -t \"stash\${APP:+/\$APP}[$$]\" -p $_level \"\$@\";
    }"
  elif [ -n "$_std" ]; then
    eval "LOG_$_level() {
      $_maybedebug
      echo \"stash\${APP:+/\$APP}[$$] $_level\" \"\$@\" >&2;
    }"
  else
    eval "LOG_$_level() { :; }"
  fi
}

for _lv in alert crit debug emerg err error info notice panic warn warning
do _make_logger $_lv stdio; done

quiet_log() {
  for _lv in alert crit debug emerg err error info notice panic warn warning
  do _make_logger $_lv; done
}

die_unsupported() {
  LOG_error 'Unsupported platform'${@:+": $@"} # Surprisingly, this works well.
  exit 1
}

fail() { LOG_error "$@"; exit 1; }

[ "$stash" != "${stash#/}" ] || fail "'stash' must be an absolute path"

atdie() { stash_trap="$stash_trap $*"; }
trap 'set +e; for c in $stash_trap; do $c; done' ERR
atexit() { stash_dirty="$stash_dirty $*"; }
_trap='set +e;
if [ -n "$debug" ]; then
  for c in $stash_dirty; do [ "$c" != "${c%_nodebug}" ] || $c; done;
else
  for c in $stash_dirty; do $c; done;
fi'
trap "$_trap" EXIT

on() { _get_on; echo $s_on; }

on_centos()  { _get_on && [ $s_on = centos ]; }
on_debian()  { _get_on && [ $s_on = debian ]; }
on_devuan()  { _get_on && [ $s_on = devuan ]; }
on_deb()     { on_debian || on_devuan; }
on_openbsd() { _get_on && [ $s_on = openbsd ]; }
on_linux()   { on_deb || on_centos; }
on_bsd()     { on_openbsd; }
on_systemd() { die_unsupported; }

_get_want() { : ${os_platform:=$(on)}; }
want() { _get_want; echo $os_platform; }

want_centos()  { _get_want && [ $os_platform = centos ]; }
want_debian()  { _get_want && [ $os_platform = debian ]; }
want_devuan()  { _get_want && [ $os_platform = devuan ]; }
want_deb()     { want_debian || want_devuan; }
want_openbsd() { _get_want && [ $os_platform = openbsd ]; }
want_linux()   { want_deb || want_centos; }
want_bsd()     { want_openbsd; }
want_systemd() { die_unsupported; }


root() { [ $(id -u) = 0 ] && "$@"; }

set_cli() { for _var in $cli; do eval $_var=\$cli__$_var; done; }
cli() {
  if [ -z "$2" -a "$1" != "${1#[ 	]*}" ]; then
    fail Invalid whitespace
  fi
  cli="$cli $1"
  eval "cli__$1=\$2"
}

stash() {
  set -e
  local _how=$1
  shift
  case "$_how" in
  apply) _role_finish;;
  env) _env_load "$1";;
  role) for _role; do _role_load $_role; done;;
  settings) _role_settings "$@";;
  /*) _role_finish; finish=$(date); _stash_save "$_how";;
  *) role do "$_how" "$@";;
  esac
}

get() {
  LOG_debug "Downloading $1 to ${2:-stdout}"
  if on_openbsd; then ftp -o"${2:--}" "$1"
  else die_unsupported; fi
}

copy_function() { _fn=$(typeset -f $1); eval "$2${_fn#$1}"; }

append_var()  { _var=$1; shift; for _val; do eval "$_var=\"\$$_var \$_val\""; done; }
prepend_var() { _var=$1; shift; for _val; do eval "$_var=\"\$_val \$$_var\""; done; }
append_pair() { eval "$1=\"\$$1 $2:$3\""; }
contains() { for _this in $1; do if [ $_this = $2 ]; then return 0; fi; done; return 1; }
paired() {
  _q= ; if [ "$1" = -q ]; then shift; _q=1; fi
  for _this in $1; do
    if [ ${_this#*:} = $2 ]; then [ -n "$_q" ] || echo ${_this%%:*}; return 0; fi
  done
  return 1
}
remember() {
  for _var; do
    paired "$stashed_var" $_var || append_pair stashed_var $running_role $_var
  done
}

chmkdir() { _m=$1; shift; [ -n "$2" ] && local _o=$1 && shift;
            mkdir -p "$@"; [ -n "$_o" ] && chown $_o "$@"; chmod $_m "$@"; }
chtouch() { _m=$1; shift; [ -n "$2" ] && local _o=$1 && shift;
            touch "$@"; [ -n "$_o" ] && chown $_o "$@"; chmod $_m "$@"; }

line_in_file() { [ -e "$2" ] && grep -qFx "$1" "$2" || echo "$2" >> "$1"; }

# This relies on the fact that the first time stash is run, type will
# not be created until it's finished.
on_firsttime() { ! [ -e /etc/stash/type ]; }

get_fslayout() {
  if [ -e "$os_fslayout" ]; then cat "$os_fslayout"
  else cat "$LIBSTASH"/iso/layout.$(want)-"$os_fslayout"; fi
}

_get_on() {
  [ -n "$s_on" ] && return
    if [ -e /etc/centos-release ]; then s_on=centos
  elif [ -e /etc/debian_version ]; then s_on=debian
  elif [ -e /etc/devuan_version ]; then s_on=devuan
  elif [ "`uname`" = OpenBSD ];    then s_on=openbsd
  else die_unsupported unknown; fi
}

_stash_save() {
  _dest=$1

  _old= _new=
  for _v in $(set | grep '^__OLD__.*=' | cut -d= -f1); do unset $_v; done
  if [ -e "$_dest" ]; then
    while read _line; do _old="$_old __OLD__${_line% # *}"; done < "$_dest"
    eval "$_old"
  fi

  exec 3>&1
  [ -n "$_dest" ] && exec >>"$_dest"

  set +e
  for _pair in stash fqdn role environment id loaded_roles $stashed_var; do
    _var=${_pair#*:} _from_role=${_pair%%:*}
    eval "[ \"\${$_var# }\" != \"\$__OLD__$_var\" ]" || continue # skip anything unchanged
    if [ -z "$_new" ]; then
      [ -z "$_old" ] || echo
      echo start=\""$start"\"
      echo finish=\""$finish\""
      _new=old
    fi
    # TODO: protect against metacharacters, also in append_var etc.
    # nb. \ doesn't protect spaces in for x in $unprotected_var; ...
    # Until this TODO is TODone, no value stored in a variable named
    # in $stashed_var can contain a character which is magical.
    _comment="From role $_from_role"; [ "$_from_role" != "$_pair" ] || _comment=
    eval echo "\"$_var=\\\"\${$_var# }\\\"${_comment:+ # $_comment}\""
  done

  exec >&3 3>&-
}

_maybe_copy() {
  set -e
  if [ "$1" = -f ]; then _force=1; shift; else _force= ; fi
  local _src=$1 _dst=$2 _mode=${3:-0444} _own=${4:-0:0}

  if [ -n "$_force" -o ! -e "$_dst" ] || ! diff -q "$_src" "$_dst" > /dev/null 2>&1; then
    chtouch $_mode $_own "$_dst"
    cat "$_src" > "$_dst"
    return 101
  else
    # test first? *_changed=acl
    chown $_own "$_dst"
    chmod $_mode "$_dst"
  fi
}