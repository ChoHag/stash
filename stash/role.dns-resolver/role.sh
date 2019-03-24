#!sh

role_settings() { on_openbsd || die_unsupported; }

role_apply() {
  set -e
  if on_openbsd; then
    # Nothing to install, unbound is built in
    stash config copy unbound.conf /var/unbound/etc/unbound.conf
    # For convenience
    ln -sfn /var/unbound/etc/unbound.conf /etc/unbound.conf
    stash daemon enable unbound
    stash config line 'ignore domain-name;' /etc/dhclient.conf
    stash config line 'ignore domain-name-servers;' /etc/dhclient.conf
  fi
}
