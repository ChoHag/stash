#!/bin/sh

# Upgrade beyond plain bourne shell if possible
[ -z "$SH_VERSION" ] && which ksh >/dev/null 2>&1 && exec ksh "$0" "$@"
[ -z "${SH_VERSION:-$BASH_VERSION}" ] && which bash >/dev/null 2>&1 && exec bash "$0" "$@"

set -e

: ${LIBSTASH:=${stash:=$(dirname -- "$0")}}

runinit() {
  . "$LIBSTASH"/libstash.sh
  repo=$LIBSTASH
  if [ -e /etc/stash/type ]; then
    . /etc/stash/type
    loaded_roles= loaded_env=
    hostname=${fqdn%%.*} domain=${fqdn#*.}
  elif [ -e "$stash"/id ]; then
    . "$stash"/id # skip _stash_id's verification # TODO: make it optional
  fi
  if [ -n "$environment" ]; then
    LOG_notice Loading environment definition
    stash env "$environment"
  fi
}

reinit() {
  for _s; do eval "_save_$_s=\$$_s"; done
  runinit
  for _s; do eval "$_s=\$_save_$_s"; done
}

runinit

if [ $# -ne 0 ]; then # identified from the command-line
  case "$1" in
  -q|--quiet) quiet_log;;
  -h|--help) echo "Don't panic!"; exit;;
  -*) echo "stash/run doesn't accept any options except -q(uiet)" >&2; exit 1;;
  esac
  role=${1%%/*}         # The primary role of this server
  : ${role:?No role}
  if [ -z "$environment" ]; then
    environment=${1#*/} # The environment intended for this server
    [ "$environment" = "$1" ] && environment=$default_environment
  fi
  fqdn=${2:-$role-0.$environment.stashed}
  hostname=${fqdn%%.*} domain=${fqdn#*.}
fi

[ $(id -u) = 0 ] || fail stash/run must be executed as root

start=$(date)

mkdir -p /etc/stash
echo being-built ... > /etc/stash/environment # Safety valve

if on_firsttime; then
  LOG_notice Possibly stopping crond
  if   on_centos; then systemctl stop crond
  elif on_linux; then /etc/init.d/cron stop
  fi
fi

LOG_notice Preparing core
stash role config
stash role keys

LOG_notice Loading supplemental stash sources
stash role firewall
stash role network
stash role supplement

LOG_notice Applying early roles to obtain supplement
stash apply

LOG_notice Reload updated roles and libraries
reinit domain environment fqdn hostname role start \
  loaded_roles s_can_file s_can_method # ← So we don't have to re-load roles

# If there was no identification on the command-line it should have
# come from the supplement by now
if [ $# -eq 0 ]; then
  stash read-id
fi

# Load any settings which may have changed
stash settings $loaded_roles

LOG_notice Loading common stash roles
stash role pkg
stash role daemon
stash role date
stash role log
stash role users
stash role cron
stash role tls
stash role crash

LOG_notice Specialising server
stash role $role
stash role environment

LOG_notice Applying all roles and saving to /etc/stash/type
stash /etc/stash/type

if [ "$environment" = prod -o "$environment" = production ]; then
  environment=$(echo $environment | tr a-z A-Z)
fi
echo $environment $role $(date) > /etc/stash/environment

LOG_notice Finished
