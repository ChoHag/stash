#!sh
# Ensure a strict firewall is set up by default, possibly role methods
# to permit incoming connections
role_apply() {
  if on_openbsd; then
    stash config take /etc/pf.conf shared
  fi
}
