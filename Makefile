DESTDIR=/
PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
LIBSTASH=$(PREFIX)/share/stash
RBINDIR=$(DESTDIR)$(BINDIR)
RLIBSTASH=$(DESTDIR)$(LIBSTASH)

srcs=mkautoiso.sh \
  mkclone.sh      \
  mkenv.sh        \
  mkinstance.sh   \
  mkstash.sh      \
  mkstashfs.sh    \
  mkvm.sh         \
  read-layout.pl  \
  restash.sh      \
  runvm.sh

corelib=libstash-mk.sh  \
  libstash-hvm.sh       \
  libstash-hvm-vmd.sh   \
  libstash-hvm-nbsvm.sh

isofiles=                  \
  libiso.build-openbsd.sh  \
  libiso.target-centos.sh  \
    installer.centos       \
  libiso.target-devuan.sh  \
    installer.devuan       \
  libiso.target-openbsd.sh \
    installer.openbsd      \
    layout.openbsd-default \
    layout.openbsd-full    \
    layout.openbsd-minimal \
    layout.openbsd-simple

stashsrcs=run.sh

stashlib=libstash.sh libstash-env.sh libstash-role.sh libstash-net.sh libstash-sht.sh

stashdata=                   \
  post-hook.centos.sh        \
  post-hook.deb.sh           \
  post-hook.head.sh          \
  post-hook.openbsd.sh       \
  post-hook.openbsd-clone.sh \
  rc.local.firsttime

coreroles=            \
  config/role.sh      \
  firewall/role.sh    \
  keys/role.sh        \
  network/role.sh     \
  supplement/role.sh

roles=                 \
  crash/role.sh        \
  cron/role.sh         \
  daemon/role.sh       \
  date/role.sh         \
  dns-resolver/role.sh \
    dns-resolver/unbound.conf \
  environment/role.sh  \
  log/role.sh          \
  nothing/role.sh      \
  pkg/role.sh          \
  router/role.sh       \
  ssh/role.sh          \
    ssh/request-host-certificate-ssh \
  tls/role.sh          \
  tor/role.sh          \
    tor/replace-sht.etc_-^tor_-^torrc        \
    tor/replace-sht.etc_-^tor_-^torrc.divert \
    tor/replace-sht.etc_-^tor_-^torrc.relay  \
    tor/tor.socks.acl                        \
  users/role.sh

# TODO: Don't use copy/sed
install:
	mkdir -p $(RBINDIR)
	mkdir -p $(RLIBSTASH)/iso
	mkdir -p $(RLIBSTASH)/lib
	for _f in $(srcs);      do sed 's,LIBSTASH:=.*,LIBSTASH=$(LIBSTASH)},g' \
	                             < src/$$_f > $(RBINDIR)/$${_f%.??}; \
	                           chmod 755 $(RBINDIR)/$${_f%.??}; done
	for _f in $(corelib);   do cp lib/$$_f $(RLIBSTASH)/lib/$$_f; done
	for _f in $(isofiles);  do cp iso/$$_f $(RLIBSTASH)/iso/$$_f; done
	for _f in $(stashsrcs); do cp src/$$_f $(RLIBSTASH)/$$_f; done
	for _f in $(stashlib);  do cp $$_f $(RLIBSTASH)/$$_f; done
	for _f in $(stashdata); do cp lib/$$_f $(RLIBSTASH)/lib/$$_f; done
	for _f in $(coreroles); do mkdir -p $(RLIBSTASH)/lib/role.$${_f%/*}; \
	                           cp core/role.$$_f $(RLIBSTASH)/lib/role.$${_f%/*}; done
	for _f in $(roles);     do mkdir -p $(RLIBSTASH)/role.$${_f%/*}; \
	                           cp stash/role.$$_f $(RLIBSTASH)/role.$${_f%/*}; done
