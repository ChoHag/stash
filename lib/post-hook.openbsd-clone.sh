# Change disklabel's UID
for _d in $(dmesg | grep -E ^sd[0-9]+: | cut -d: -f1 | sort -u); do
  if _label=$(disklabel $_d); then
    _old=$(echo "$_label" | awk '$1 == "duid:" { print $2 }')
    echo 'i\n0000000000000000\nw' | disklabel -E $_d
    _new=$(disklabel sd0 | awk '$1 == "duid:" { print $2 }')
    echo "%s/^$_old/$_new/\nw" | ed -s /etc/fstab
  fi
done

syspatch
