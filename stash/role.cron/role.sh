#!sh

# Ensure crond is ready, stash role to manage cron tabs

role_settings() {
  role method tab _cron_register_crontab
}

_cron_register_crontab() {
  ...
}
