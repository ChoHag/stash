#!sh

# Role methods to manage daemons

role_settings() {
  role_method disable _daemon_disable
  role_method enable _daemon_enable
  role_method reload _daemon_reload
  role_method restart _daemon_restart
  role var enabled
  role var disabled
  remember daemon_enabled daemon_disabled
}

if on_openbsd; then

  _daemon_disable() {
    daemon_changed=
    for _daemon; do
      LOG_info ... disable $_daemon
      if [ "$(rcctl get $_daemon | grep ^${_daemon}_flags | cut -d= -f2)" != NO ]; then
        rcctl disable "$_daemon"
        append_var daemon_changed $_daemon
      fi
      append_var daemon_disabled "$_daemon"
    done
  }

  _daemon_enable() {
    daemon_changed=
    for _daemon; do
      LOG_info ... enable $_daemon
      if [ "$(rcctl get $_daemon | grep ^${_daemon}_flags | cut -d= -f2)" = NO ]; then
        rcctl enable "$_daemon"
        append_var daemon_changed $_daemon
      fi
      append_var daemon_enabled "$_daemon"
    done
  }

  _daemon_reload() {
    daemon_changed= # Doesn't track anything
    for _daemon; do
      LOG_info ... reload $_daemon
      if rcctl check "$_daemon" >/dev/null 2>&1; then rcctl reload "$_daemon"; fi
    done
  }

  _daemon_restart() {
    daemon_changed= # Doesn't track anything
    for _daemon; do
      LOG_info ... restart $_daemon
      if rcctl check "$_daemon" >/dev/null 2>&1; then rcctl restart "$_daemon"; fi
    done
  }

fi
