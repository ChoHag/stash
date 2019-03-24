#!sh
# Role methods to do networking

role_apply() {
  set -e
  if on_firsttime; then
    find /etc -type f | xargs grep -l changeme | while read f; do
      LOG_info ... host name in $f
      [ -n "$hostname" ] && printf '/changemehost/s//%s/\nw\n' $hostname | ed -s $f 2>/dev/null || true
      [ -n "$domain"   ] && printf '/changemedomain/s//%s/\nw\n' $domain | ed -s $f 2>/dev/null || true
    done
    hostname $(cat /etc/myname) # TODO: openbsd only
  fi
}
