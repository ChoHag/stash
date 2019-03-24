#!sh

# Ensure syslog & rotation are ready, role method to register logfile

role_settings() {
  role_method logfile _syslog_logfile
}

_syslog_logfile() {
  ...
}
