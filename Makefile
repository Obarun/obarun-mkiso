# Makefile for obarun-mkiso

VERSION = $$(git describe --tags| sed 's/-.*//g;s/^v//;')
PKGNAME = obarun-mkiso

BINDIR = /usr/bin

FILES = $$(find mkiso/ -type f)
SCRIPTS = 	obarun-mkiso.in \
			mkiso.sh
EXTRA = efiboot \
		isolinux \
		syslinux
		
install:
	
	for i in $(SCRIPTS) $(FILES); do \
		sed -i 's,@BINDIR@,$(BINDIR),' $$i; \
	done
	
	install -Dm755 obarun-mkiso.in $(DESTDIR)/$(BINDIR)/obarun-mkiso
	install -Dm755 mkiso.sh $(DESTDIR)/usr/lib/obarun/mkiso.sh
	
	for i in $(FILES); do \
		install -Dm755 $$i $(DESTDIR)/usr/lib/obarun/$$i; \
	done
	
	install -Dm644 mkiso.conf $(DESTDIR)/etc/obarun/mkiso.conf
	
	install -Dm644 mkinitcpio.conf $(DESTDIR)/var/lib/obarun/obarun-mkiso/mkinitcpio.conf
	install -Dm644 pacman.conf $(DESTDIR)/var/lib/obarun/obarun-mkiso/pacman.conf
	
	for i in $(EXTRA); do
		cp -aT $$i $(DESTDIR)/var/lib/obarun/obarun-mkiso/$$i
	done
	
	install -Dm644 PKGBUILD $(DESTDIR)/var/lib/obarun/obarun-mkiso/update_package/PKGBUILD
	
	install -Dm644 LICENSE $(DESTDIR)/usr/share/licenses/$(PKGNAME)/LICENSE

version:
	@echo $(VERSION)
	
.PHONY: install version
