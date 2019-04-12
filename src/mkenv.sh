#!/bin/sh

# Generate envdir and stash signing key

: ${LIBSTASH:=$PWD} # /usr/local/share/stash
. "$LIBSTASH"/libstash.sh
APP=mkenv

nopass= key= secdir=$HOME/.stash
while getopts hDd:k:Ns:S: _opt; do case "$_opt" in
  \?) usage;;
  h) echo "Don't panic!"; usage;;    # --help
  D) cli debug         true;;        # --debug

  d) cli domain       "$OPTARG";;    # --domain
  k) cli key          "$OPTARG";;    # --key-name
  N) cli nopass       yes;;          # --no-password
  s) cli sign         "$OPTARG";;    # --sign
  S) cli secdir       "$OPTARG" ws;; # --secret-path

  # -) --long-argument;;

esac; done
shift $(($OPTIND-1))

envdir=${1:?No environment}
name=${2:-${envdir##*/env.}} name=${name#env.}
if [ "${envdir#env.}" = "$name" ]; then
  repo=$PWD envdir=env.$name
else
  repo=${envdir%/env.$name}
fi

if [ "$repo" = "${repo#/}" ]; then
  die repository path must be absolute
fi

if [ -e "$repo"/org.sh ]; then . "$repo"/org.sh; fi
set_cli
if [ -n "$secdir" -a "$secdir" = "${secdir#/}" ]; then
  die secret key path must be absolute
fi
: ${key:=${org:+$org-}$name-0}
secpath=${secdir:-$HOME/.stash}/$key-stash.sec # TODO: default $HOME/.stash/$org/*.sec
pubpath=$repo/$envdir/$key-stash.pub

if [ ! -e "$secpath" ]; then chmkdir 0700 "$(dirname "$secpath")"
else :; fi # TODO: Check permission of secret's directory and abort if bad

if [ ! -e "$repo/$envdir" ]; then mkdir "$repo/$envdir" || die mkdir "$repo/$envdir";
elif [ -e "$repo/$envdir"/env.sh ]; then die environment already exists; fi

if ! signify -G ${nopass:+-n} -c "$key stash" -p "$pubpath" -s "$secpath"; then
  rmdir "$repo/$envdir" # also only if it was made but meh
  die signify
fi

exec >> "$repo/$envdir"/env.sh
echo "stash_pubkey=\"${pubpath#$repo/}\""
echo "stash_key=\"$secpath\""
echo "env=\"$name\""
[ -n "$cli__domain" ] && echo "domain=\"$domain\"" # Only from the cli
