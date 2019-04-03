#!sh

# Handling environments; like roles except only one but needn't exist?

# mk* tools plus restash and runvm expect $env on cli (via $envdir) or
# use $default_environment from stash/org
# except mkenv: sort of
#   mkautoiso: not accepted
#   mkclone: unused
#
# run.sh is special
#   may be started with explicit role/environment/name at cli
#     undefined what happens if this is done other than first time
#   first time may or may not start with none
#   then supplement provides id and restart
#     error if supplement attempts to change environment
#   subsequent times obtained from /etc/stash/type
#
# Also pre/post hooks provided to installer

_env_load() {
  local _loading_env=$1 _old_env=$env
  if [ -e "$repo/org.sh" ]; then
    . "$repo/org.sh"; _r=$?
    if [ "$_r" != 0 -o \( -n "$_old_env" -a "$env" != "$_old_env" \) ]; then
      fail Invalid organisation "$repo"
    fi
  fi
  [ -e "$repo/env.$_loading_env/env.sh" ] || return 0
  env_apply() { :; }
  . "$repo/env.$_loading_env/env.sh"; _r=$?
  if [ "$_r" != 0 -o -z "$env" -o \( -n "$_old_env" -a "$env" != "$_old_env" \) ]; then
    fail Invalid environment "$repo/env.$_loading_env/env.sh"
  fi
  [ -z "$loaded_env" ] && LOG_notice "Loaded environment $_loading_env"
  loaded_env=$_loading_env
}

find_environment() { # get $env and $envdir from $envdir
  set_cli
  _env_load # for org.sh
  : ${envdir:=${repo:-/nonexistent}/env.$default_environment}
  if [ -e "$envdir" ]; then
    env=${envdir##*env.}
    if [ "$envdir" = "$env" ]; then fail Invalid environment: "$envdir"; fi
  elif [ -e "${repo:-/nonexistent}/env.$envdir" ]; then
    env=$envdir
    envdir="$repo/env.$env"; cli envdir "$envdir"
  elif [ -n "$envdir" ]; then
    fail Cannot find environment $envdir
  fi
  _env_load "$env"
  set_cli
}
