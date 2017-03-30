# Maintainer: Obarun-mkiso scripts <eric@obarun.org>
# DO NOT EDIT this PKGBUILD if you don't know what you do

pkgname=obarun-mkiso
pkgver=23536df
pkgrel=1
pkgdesc=" Script for making an iso"
arch=(x86_64)
url="file:///var/lib/obarun/$pkgname/update_package/$pkgname"
license=('BEERWARE')
depends=('git' 'pacman' 'obarun-libs' 'squashfs-tools' 'libisoburn' 'gzip' 'archiso' 'syslinux')
backup=('etc/obarun/mkiso.conf')
install=
source=("$pkgname::git+file:///var/lib/obarun/$pkgname/update_package/$pkgname")
md5sums=('SKIP')
validpgpkeys=('6DD4217456569BA711566AC7F06E8FDE7B45DAAC') # Eric Vidal

pkgver() {
	cd "${pkgname}"
	if git_version=$(git rev-parse --short HEAD); then
		read "$rev-parse" <<< "$git_version"
		printf '%s' "$git_version"
	fi
}

package() {
	cd "$srcdir/$pkgname"

	install -Dm 0755 "obarun-mkiso.in" "$pkgdir/usr/bin/obarun-mkiso"
	install -Dm 0644 "mkiso_functions" "$pkgdir/usr/lib/obarun/mkiso_functions"
	install -Dm 0755 "build_iso" "$pkgdir/usr/lib/obarun/build_iso"
	install -Dm 0755 "make_iso" "$pkgdir/usr/lib/obarun/make_iso"
	install -Dm 0644 "mkiso.conf" "$pkgdir/etc/obarun/mkiso.conf"
	install -dm 0755 "$pkgdir/usr/share/licenses/obarun-mkiso/"
	install -Dm 0644 "LICENSE" "$pkgdir/usr/share/licenses/obarun-mkiso/LICENSE"
	install -Dm 0644 "PKGBUILD" "$pkgdir/var/lib/obarun/obarun-mkiso/update_package/PKGBUILD"
	
	install -dm 0755 "$pkgdir/var/lib/obarun/obarun-mkiso"
	install -Dm 0644 "mkinitcpio.conf" "$pkgdir/var/lib/obarun/obarun-mkiso/mkinitcpio.conf"
	install -Dm 0644 "pacman.conf" "$pkgdir/var/lib/obarun/obarun-mkiso/pacman.conf"
	
	for d in efiboot isolinux syslinux; do
		cp -aT "${d}" "$pkgdir/var/lib/obarun/obarun-mkiso/${d}"
	done	

}

