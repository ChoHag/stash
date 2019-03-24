#!sh

# Handling environments; like roles except only one but needn't exist?

# TODO: merge these

_env_load() {
  [ -z "$loaded_env" ] || return 1 # unnecessary?
  _env=$1
  [ -e "$stash/env.$_env/env.sh" ] || return 0
  LOG_notice "Loading environment $_env"
  env_apply() { :; }
  if [ -e "$stash/org.sh" ]; then . "$stash/org.sh"; fi
  . "$stash/env.$_env/env.sh"; _r=$?
  loaded_env=$_env
  return $_r
}

find_environment() {
  set_cli
  if [ -n "$repo" -a -e "$repo/org.sh" ]; then . "$repo/org.sh"; fi
  : ${envdir:=$repo/env.$default_environment}
  if [ -e "$envdir" ]; then
    env=${envdir##*.}
    if [ "$envdir" = "$env" ]; then fail Invalid environment: "$envdir"; fi
  elif [ -e "${repo:-/nonexistent}/env.$envdir" ]; then
    env=$envdir
    envdir="$repo/env.$env"; cli envdir "$envdir"
  elif [ -n "$envdir" ]; then
    fail Cannot find environment $envdir
  fi
  local _env=$env
  if [ -e "$envdir/env.sh" ]; then . "$envdir/env.sh"; fi
  if [ "$env" != "$_env" ]; then fail Invalid environment: "$_env"; fi
  set_cli
}
