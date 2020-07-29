machine-url = https://ops.zingle.me/public/machine
portable-url = https://ops.zingle.me/public/portable
publish-host = ops.zingle.me
publish-path = /usr/share/zingle/ops/public/portable

build = build
src = src

portables = php-fpm nginx network dig curl ca
portable-images = $(patsubst %,$(build)/%.tgz,$(portables))
portable-folders = $(patsubst %,$(build)/%,$(portables))
portable-cleans = $(patsubst %,clean-%,$(portables))
portable-pubs = $(patsubst %,publish-%,$(portables))

systems = eoan
system-downloads = $(patsubst %,download-%,$(systems))
system-installs = $(patsubst %,install-%,$(systems))
system-uninstalls = $(patsubst %,uninstall-%,$(systems))
system-reinstalls = $(patsubst %,reinstall-%,$(systems))

default: build

build: $(portables)

clean:
	rm -rf $(build)

$(portable-cleans): clean-%:
	rm -rf $(build)/$* $(build)/$*.tgz

$(portable-pubs): publish-%: $(build)/%.published

$(build)/%.published: $(build)/%.tgz
	$(eval name := $(shell basename $^ .tgz))
	$(eval ver := $(shell tar xzf $^ ./etc/os-release -O | grep ^VERSION= | sed -e s/.*=//))
	$(eval hash := $(shell md5sum $^ | cut -d" " -f1))
	scp $^ $(publish-host):$(publish-path)/$(name)-$(ver)-$(hash).tgz
	ssh $(publish-host) ln -nsf $(name)-$(ver)-$(hash).tgz $(publish-path)/$(name)-$(ver).tgz
	touch $@

$(build)/eoan:
	sudo make install-eoan

$(build)/ca: $(build)/eoan Makefile
	$(eval pwd := $(shell pwd))
	mkdir -p $@/etc/ssl/certs $@/usr/share/ca-certificates
	sudo systemd-nspawn -qbPD $< -M portable-build \
		--overlay=$(pwd)/$</etc/ssl/certs:$(pwd)/$@/etc/ssl/certs:/etc/ssl/certs \
		--overlay=$(pwd)/$</usr/share/ca-certificates:$(pwd)/$@/usr/share/ca-certificates:/usr/share/ca-certificates &
	@sleep 3
	machinectl shell portable-build /usr/bin/find /etc/ssl/certs /usr/share/ca-certificates -type f -exec touch -h {} +
	machinectl shell portable-build /usr/bin/find /etc/ssl/certs /usr/share/ca-certificates -type l -exec touch -h {} +
	machinectl stop portable-build
	@sleep 3
	sudo chown -R $(shell whoami):$(shell whoami) $@
	echo VERSION=eoan > $@/etc/os-release
	touch $@
	sudo make uninstall-eoan

$(build)/dig: $(build)/eoan $(src)/dig.release Makefile
	$(eval pwd := $(shell pwd))
	bin/mkproot $@
	rm -fr $@/etc/*
	sudo systemd-nspawn -qbPD $< -M portable-build --overlay=$(pwd)/$</etc:$(pwd)/$@/etc:/etc --overlay=$(pwd)/$</usr:$(pwd)/$@/usr:/usr &
	@sleep 3
	machinectl shell portable-build /usr/bin/apt-get -y install --reinstall dnsutils bind9-host libbind9-161 libdns1104 libisc1100 libisccfg163 liblwres161 libc6 libidn2-0 libirs161 libkrb5-3 libgssapi-krb5-2 libjson-c4 libxml2 libssl1.1 libunistring2 libk5crypto3 libcom-err2 libkrb5support0 libkeyutils1 libicu63 zlib1g liblzma5 libstdc++6 libgcc1
	machinectl stop portable-build
	@sleep 3
	sudo chown -R $(shell whoami):$(shell whoami) $@
	touch $@/etc/machine-id
	echo nameserver 127.0.0.53 >> $@/etc/resolv.conf
	echo options edns0 >> $@/etc/resolv.conf
	cp $(src)/dig.release $@/etc/os-release
	touch $@
	sudo make uninstall-eoan

$(build)/curl: $(build)/eoan $(src)/curl.release Makefile
	$(eval pwd := $(shell pwd))
	mkdir $@
	wget -qO- $(portable-url)/dig.tgz | tar xz -C $@
	rm -fr $@/etc/*
	sudo systemd-nspawn -qbPD $< -M portable-build --overlay=$(pwd)/$</etc:$(pwd)/$@/etc:/etc --overlay=$(pwd)/$</usr:$(pwd)/$@/usr:/usr &
	@sleep 3
	machinectl shell portable-build /usr/bin/apt-get -y install --reinstall curl libnghttp2-14 librtmp1 libssh-4 libpsl5 libldap-2.4-2 libgnutls30 libhogweed4 libnettle6 libgmp10 libsasl2-2 libgssapi3-heimdal libp11-kit0 libtasn1-6 libheimntlm0-heimdal libkrb5-26-heimdal libasn1-8-heimdal libhcrypto4-heimdal libroken18-heimdal libffi6 libwind0-heimdal libheimbase1-heimdal libhx509-5-heimdal libsqlite3-0
	machinectl shell portable-build /usr/bin/apt-get -y install --reinstall ca-certificates dash debconf
	machinectl shell portable-build /usr/sbin/dpkg-reconfigure ca-certificates
	machinectl shell portable-build /usr/sbin/update-ca-certificates
	machinectl stop portable-build
	@sleep 3
	sudo chown -R $(shell whoami):$(shell whoami) $@
	touch $@/etc/machine-id
	echo nameserver 127.0.0.53 >> $@/etc/resolv.conf
	echo options edns0 >> $@/etc/resolv.conf
	cp $(src)/curl.release $@/etc/os-release
	touch $@
	sudo make uninstall-eoan

$(build)/network: $(build)/eoan $(src)/network.release Makefile
	$(eval pwd := $(shell pwd))
	bin/mkproot $@
	rm -fr $@/etc/*
	sudo systemd-nspawn -qbPD $< -M portable-build --overlay=$(pwd)/$</etc:$(pwd)/$@/etc:/etc --overlay=$(pwd)/$</usr:$(pwd)/$@/usr:/usr &
	@sleep 3
	machinectl shell portable-build /usr/bin/apt-get -y install --reinstall \
		bind9-host ca-certificates curl dnsutils \
		iputils-ping \
		libasn1-8-heimdal \
		libbind9-161 libbsd0 libc6 libcap2 libcom-err2 libdns1104 libffi6 \
		libgcc1 \
		libgcrypt20 libgmp10 libgnutls30 libgpg-error0 \
		libgssapi-krb5-2 libgssapi3-heimdal \
		libhcrypto4-heimdal libheimbase1-heimdal libheimntlm0-heimdal \
		libhogweed4 libhx509-5-heimdal \
		libicu63 libidn2-0 \
		libirs161 \
		libisc1100 libisccfg163 \
		libjson-c4 libkeyutils1 libk5crypto3 libkrb5-3 libkrb5-26-heimdal \
		libkrb5support0 \
		libldap-2.4-2 libldap-common liblwres161 liblzma5 libnettle6 \
		libnghttp2-14 libp11-kit0 \
		libpsl5 libroken18-heimdal librtmp1 \
		libsasl2-2 libsqlite3-0 libssh-4 libssl1.1 \
		libstdc++6 \
		libtasn1-6 libunistring2 libwind0-heimdal libxml2 \
		netcat-openbsd zlib1g
	machinectl stop portable-build
	@sleep 3
	sudo chown -R $(shell whoami):$(shell whoami) $@
	touch $@/etc/resolv.conf $@/etc/machine-id
	echo nameserver 127.0.0.53 >> $@/etc/resolv.conf
	echo options edns0 >> $@/etc/resolv.conf
	cp $(src)/network.release $@/etc/os-release
	touch $@

$(build)/nginx: $(build)/eoan $(src)/nginx.release Makefile
	$(eval pwd := $(shell pwd))
	bin/mkproot $@
	rm -fr $@/etc/*
	sudo systemd-nspawn -qbPD $< -M portable-build --overlay=$(pwd)/$</etc:$(pwd)/$@/etc:/etc --overlay=$(pwd)/$</usr:$(pwd)/$@/usr:/usr &
	@sleep 3
	machinectl shell portable-build /usr/bin/apt-get -y install nginx
	machinectl stop portable-build
	@sleep 3
	sudo chown -R $(shell whoami):$(shell whoami) $@
	find $@/etc -mindepth 1 -maxdepth 1 ! -name nginx -exec rm -rf {} +
	find $@/etc/nginx/sites-enabled -mindepth 1 -exec rm -rf {} +
	touch $@/etc/resolv.conf $@/etc/machine-id
	cp $(src)/nginx.release $@/etc/os-release
	touch $@

$(build)/php-fpm: $(build)/eoan $(src)/php-fpm.release Makefile
	sudo make uninstall-$(basename $<)
	sudo make install-$(basename $<)
	$(eval pwd := $(shell pwd))
	bin/mkproot $@
	rm -fr $@/etc/*
	sudo systemd-nspawn -qbPD $< -M portable-build --overlay=$(pwd)/$</etc:$(pwd)/$@/etc:/etc --overlay=$(pwd)/$</usr:$(pwd)/$@/usr:/usr &
	@sleep 3
	machinectl shell portable-build /usr/bin/apt-get -y install \
		libnss3 php-fpm php-bcmath php-bz2 php-curl php-mbstring php-mysql php-pgsql php-soap php-xml
	machinectl stop portable-build
	@sleep 3
	sudo chown -R $(shell whoami):$(shell whoami) $@
	find $@/etc -mindepth 1 -maxdepth 1 ! -name alternatives -and ! -name php -exec rm -rf {} +
	touch $@/etc/resolv.conf $@/etc/machine-id
	echo root:x:0:0:root:/root:/bin/bash > $@/etc/passwd
	echo root:x:0: > $@/etc/group
	echo passwd: files >> $@/etc/nsswitch.conf
	echo group: files >> $@/etc/nsswitch.conf
	cp $(src)/php-fpm.release $@/etc/os-release
	# add: find sort
	sudo cat $</usr/bin/bash > $@/usr/bin/bash
	sudo cat $</usr/bin/cp > $@/usr/bin/cp
	sudo cat $</usr/bin/jq > $@/usr/bin/jq
	sudo cat $</usr/bin/less > $@/usr/bin/less
	sudo cat $</usr/bin/sed > $@/usr/bin/sed
	sudo cat $</usr/bin/which > $@/usr/bin/which
	sudo cat $</usr/lib/x86_64-linux-gnu/libnss_files.so.2 > $@/usr/lib/x86_64-linux-gnu/libnss_files.so.2
	bin/addplibs64 $@ usr/bin/bash
	bin/addplibs64 $@ usr/bin/cp
	bin/addplibs64 $@ usr/bin/jq
	bin/addplibs64 $@ usr/bin/less
	bin/addplibs64 $@ usr/bin/sed
	bin/addplibs64 $@ usr/bin/which
	bin/addplibs64 $@ usr/sbin/php-fpm7.3
	bin/addplibs64 $@ usr/lib/php/20180731/bz2.so
	bin/addplibs64 $@ usr/lib/php/20180731/curl.so
	bin/addplibs64 $@ usr/lib/php/20180731/readline.so
	chmod +x $@/usr/bin/bash $@/usr/bin/cp $@/usr/bin/jq $@/usr/bin/less $@/usr/bin/sed $@/usr/bin/which
	ln -s 7.3 $@/etc/php/current
	mkdir -p $@/run/php
	sed -i 's/^error_log = .*/error_log = syslog/' $@/etc/php/current/fpm/php-fpm.conf
	sed -i \
		-e 's/^;error_log = syslog/error_log = syslog/' \
		-e 's/^;pcre.jit=.*$$/pcre.jit=0/' \
		$@/etc/php/current/fpm/php.ini
	sed -i \
		-e /^user/d \
		-e /^group/d \
		-e 's/^;clear_env = no/clear_env = no/' \
		$@/etc/php/current/fpm/pool.d/www.conf
	touch $@

$(portable-images): $(build)/%.tgz: $(build)/%
	tar cz -C $^ . > $@

$(portables): %: $(build)/%.tgz

$(system-downloads): download-%:
	@mkdir -p $(build)
	wget -qO- $(machine-url)/$*.tgz > $(build)/$*.tgz

$(system-installs): install-%: $(build)/%.tgz
	mkdir $(build)/$*
	tar xzSf $< -C $(build)/$* || { rm -rf $(build)/$*; false; }

$(system-uninstalls): uninstall-%:
	rm -fr $(build)/$*

$(system-reinstalls): reinstall-%: $(build)/%.tgz
	rm -fr $(build)/$*
	mkdir $(build)/$*
	tar xzSf $< -C $(build)/$* || { rm -rf $(build)/$*; false; }

.PHONY: default build clean
.PHONY: $(portables)
.PHONY: $(system-downloads) $(system-installs) $(system-uninstalls) $(system-reinstalls)
