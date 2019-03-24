#!sh

role_apply() {
  if on_linux; then
    stash config line 'kernel.core_pattern = /var/crash/%e-core.%p-%s-%t' /etc/sysctl.conf
  fi
}
