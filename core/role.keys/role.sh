#!sh

role_settings() {
  role_method public _keys_public
  role_method secret _keys_secret
  keys_public= keys_secret=
  remember keys_public keys_secret
}

role_apply() {
  set -e
  if [ -n "$stash_pubkey" ]; then
    case $sign in
    signify)
      if [ "$stash_pubkey" = "${stash_pubkey#env.$environment/}" \
        -o "$stash_pubkey" = "${stash_pubkey%-stash.pub}" ]; then
        fail Invalid public key
      fi
      mkdir -p /etc/signify
      stash keys public ${stash_pubkey#env.$loaded_env/} /etc/signify/${stash_pubkey##*/}
      ;;

    gpg)
      ...
      ;;
    esac
  fi
}

_keys_public() {
  set -e
  stash config copy -t "$1" "$2"
  append_pair keys_public $running_role "$2"

  keys_changed=${config_changed:+yes}
}
