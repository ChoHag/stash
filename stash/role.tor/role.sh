#!sh

role_settings() {
  on_openbsd || die_unsupported
  stash pkg need tor
  role var dns_listen   127.0.0.1:9053
  role var relay_listen
  role var relay_outbound_address
  role var socks_acl    tor.socks.acl
  role var socks_listen 127.0.0.1:9050
  role var trans_listen 127.0.0.1:9040
}

role_apply() {
  stash daemon enable tor
}
