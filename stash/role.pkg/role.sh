#!sh

# Package management

pkg_started=

role_settings() {
  if on_openbsd; then
    role var repository https://cdn.openbsd.org/pub/OpenBSD
  fi

  role method install _pkg_install
  role method need _pkg_install_later # Useless from role_apply
  role var installed
  role var need
  role var removed
  remember pkg_installed pkg_removed
}

_pkg_install() {
  set -e
  [ -n "$pkg_started" ] || fail Cannot install packages in early environment
  if on_openbsd; then pkg_add "$@"; fi
  append_var pkg_installed "$@"
}

_pkg_install_later() { append_var pkg_need "$@"; }

role_apply() {
  set -e
  if on_openbsd; then
    on_firsttime && > /etc/installurl
    stash config line "$pkg_repository" /etc/installurl
  fi
  pkg_started=1
  if [ -n "$pkg_need" ]; then _pkg_install $pkg_need; fi
}
