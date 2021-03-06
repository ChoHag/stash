#!sh

role_settings() {
  role_method public _keys_public
  role_method secret _keys_secret
  keys_public= keys_secret=
  remember keys_public keys_secret
}

role_apply() {
  if [ -n "$stash_pubkey" ]; then
    case $sign in
    signify)
      if [ "$stash_pubkey" = "${stash_pubkey#env.$environment/}" \
        -o "$stash_pubkey" = "${stash_pubkey%-stash.pub}" ]; then
        die invalid public key
      fi
      mkdir -p /etc/signify
      stash keys public ${stash_pubkey#env.$loaded_env/} /etc/signify/${stash_pubkey##*/}
      ;;

    gpg)
      die undefined
      ;;
    esac
  fi
}

_keys_public() {
  stash config copy -t "$1" "$2"
  append_pair keys_public $running_role "$2"
  keys_changed=${config_changed:+yes}
}
