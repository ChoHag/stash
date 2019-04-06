#!sh
# Ensure a strict firewall is set up by default, possibly role methods
# to permit incoming connections

role_settings() {
  role var asis
  role var template
}

role_apply() {
  if on_openbsd; then
    stash config take /etc/pf.conf shared
    if [ -n "$firewall_asis" ]; then
      stash config copy "$firewall_asis" /etc/pf.conf
    elif [ -n "$firewall_template" ]; then
      stash config template "$firewall_template" /etc/pf.conf
    fi
    if [ -n "$config_changed" ]; then pfctl -f /etc/pf.conf; fi
  fi
}
