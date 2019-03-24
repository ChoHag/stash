#!sh

set -e

if [ -e /payload ]; then
  tar -C $_top/root -xf /payload
  if [ -e $_top/root/stash.tgz ]; then
    mkdir $_top/root/stash
    tar -C $_top/root/stash -xzf $_top/root/stash.tgz
    rm $_top/root/stash.tgz
  fi
  chown -R 0:0 $_top/root
  chmod 0700 $_top/root
fi

LIBSTASH=$_top/root/stash

. "$LIBSTASH/libstash.sh"
APP=$APP
if [ -e "$LIBSTASH/org.sh" ]; then . "$LIBSTASH/org.sh"; fi
if [ -e "$LIBSTASH/env.$env/env.sh" ]; then . "$LIBSTASH/env.$env/env.sh"; fi

inroot() { chroot $_top "$@"; }

cat >> $_top/etc/rc.firsttime <<EOF
# This is executed automatically the first time this server is launched.

# Do not run it again.

# These are called at the end, by prepare_fixup
stash=/root/stash; export stash
auto_run() { "\$stash"/run; }
auto_halt() { halt -p; }

EOF
