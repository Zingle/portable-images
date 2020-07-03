machine-url = https://ops.zingle.me/public/machine

build = build
src = src

portables = php-fpm
portable-images = $(patsubst %,$(build)/%.tgz,$(portables))
portable-folders = $(patsubst %,$(build)/%,$(portables))

systems = eoan
system-downloads = $(patsubst %,download-%,$(systems))
system-installs = $(patsubst %,install-%,$(systems))
system-uninstalls = $(patsubst %,uninstall-%,$(systems))
system-reinstalls = $(patsubst %,reinstall-%,$(systems))

default: build

build: $(portables)

clean:
	rm -rf $(build)

$(build)/php-fpm: $(build)/eoan $(src)/php-fpm.release Makefile
	$(eval pwd := $(shell pwd))
	bin/mkproot $@
	rm -fr $@/etc/*
	sudo systemd-nspawn -qbPD $< -M portable-build --overlay=$(pwd)/$</etc:$(pwd)/$@/etc:/etc --overlay=$(pwd)/$</usr:$(pwd)/$@/usr:/usr &
	@sleep 5
	machinectl shell portable-build /usr/bin/apt-get -y install \
		libnss3 php-fpm php-bcmath php-bz2 php-curl php-mbstring php-mysql php-pgsql php-soap php-xml
	machinectl stop portable-build
	@sleep 5
	sudo chown -R $(shell whoami):$(shell whoami) $@
	find $@/etc -mindepth 1 -maxdepth 1 ! -name alternatives -and ! -name php -exec rm -rf {} +
	touch $@/etc/resolv.conf $@/etc/machine-id
	echo root:x:0:0:root:/root:/bin/bash > $@/etc/passwd
	echo root:x:0: > $@/etc/group
	echo passwd: files >> $@/etc/nsswitch.conf
	echo group: files >> $@/etc/nsswitch.conf
	cp $(src)/php-fpm.release $@/etc/os-release
	sudo cat $</usr/bin/cp > $@/usr/bin/cp
	sudo cat $</usr/bin/sed > $@/usr/bin/sed
	sudo cat $</usr/lib/x86_64-linux-gnu/libnss_files.so.2 > $@/usr/lib/x86_64-linux-gnu/libnss_files.so.2
	bin/addplibs64 $@ usr/bin/cp
	bin/addplibs64 $@ usr/bin/sed
	bin/addplibs64 $@ usr/sbin/php-fpm7.3
	bin/addplibs64 $@ usr/lib/php/20180731/bz2.so
	bin/addplibs64 $@ usr/lib/php/20180731/curl.so
	bin/addplibs64 $@ usr/lib/php/20180731/readline.so
	chmod +x $@/usr/bin/cp $@/usr/bin/sed
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
