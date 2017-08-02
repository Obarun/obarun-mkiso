#!/usr/bin/bash
#
# Authors:
# Eric Vidal <eric@obarun.org>
#
# Copyright (C) 2015-2017 Eric Vidal <eric@obarun.org>
#
## This script was made for provide obarun environment. This scripts is under license BEER-WARE.
# "THE BEER-WARE LICENSE" (Revision 42):
# <eric@obarun.org> wrote this file.  As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.   Eric Vidal
#
# This script contains a large part of archiso applications from Archlinux, but it was modified for purpose goal.

##		Check is the functions file exits

sourcing(){
	
	local list
	
	for list in /etc/obarun/mkiso.conf /usr/lib/obarun/{util.sh,mkiso.sh}; do
		if [[ -f "${list}" ]]; then
			source "${list}"
		else
			out_error "Missing file : ${list}"
			exit	
		fi
	done
	
	unset list
}
sourcing

run_once() {
    if [[ ! -e ${WORK_DIR}/build.${1} ]]; then
        $1
        touch ${WORK_DIR}/build.${1}
    fi
}
# define verbosity

if [[ "$VERBOSE" == "yes" ]]; then
	d_verbose='-v'
fi

make_rootfs() {
	mkdir -p ${WORK_DIR}/airootfs
	out_action "Copy $NEWROOT to $WORK_DIR/airootfs, this may take some time..."
	# Can be fail here if old version of cp is used
	# Old cp version doesn't create directories /dev/{pts,shm}
    cp -af ${NEWROOT}/* ${WORK_DIR}/airootfs
    # Erase fstab
    rm ${WORK_DIR}/airootfs/etc/fstab
}

# Needed packages for x86_64 EFI boot
make_extra_packages() {
	out_action "Install needed extra-packages"
	pacman -r "${WORK_DIR}/airootfs" -Sy efitools intel-ucode memtest86+ mkinitcpio-nfs-utils nbd --config "$PAC_CONF" --cachedir "$CACHE_DIR" --noconfirm 2>/dev/null || die " Failed to install extra-packages" "clean_install"
}

# Copy mkinitcpio archiso hooks and build initramfs (airootfs)
make_setup_mkinitcpio() {
    out_action "Set hook for initcpio"
    local _hook
  
    for _hook in archiso archiso_shutdown archiso_loop_mnt; do
        cp /usr/lib/initcpio/hooks/${_hook} ${WORK_DIR}/airootfs/etc/initcpio/hooks
        cp /usr/lib/initcpio/install/${_hook} ${WORK_DIR}/airootfs/etc/initcpio/install
    done
    
    sed -i "s|/usr/lib/initcpio/|/etc/initcpio/|g" ${WORK_DIR}/airootfs/etc/initcpio/install/archiso_shutdown
    cp /usr/lib/initcpio/install/archiso_kms ${WORK_DIR}/airootfs/etc/initcpio/install
    cp /usr/lib/initcpio/archiso_shutdown ${WORK_DIR}/airootfs/etc/initcpio
    # verification si le fichier mkinitcpio exist ou pas
    cp ${HOME_PATH}/mkinitcpio.conf ${WORK_DIR}/airootfs/etc/mkinitcpio-archiso.conf
    out_action "Create an initial ramdisk environment"
    chroot ${WORK_DIR}/airootfs/ /usr/bin/mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img

}


# Prepare kernel/initramfs ${INSTALL_DIR}/boot/
make_boot() {
	out_action "Prepare initial ramdisk boot"
    mkdir -p ${WORK_DIR}/iso/${INSTALL_DIR}/boot/${ARCH}
    cp ${WORK_DIR}/airootfs/boot/archiso.img ${WORK_DIR}/iso/${INSTALL_DIR}/boot/${ARCH}/archiso.img
    cp ${WORK_DIR}/airootfs/boot/vmlinuz-linux ${WORK_DIR}/iso/${INSTALL_DIR}/boot/${ARCH}/vmlinuz
}

# Add other aditional/extra files to ${INSTALL_DIR}/boot/
make_boot_extra() {
	out_action "Prepare extra-packages for boot"
	#memtest doit etre installer intel-ucode aussi
    cp ${WORK_DIR}/airootfs/boot/memtest86+/memtest.bin ${WORK_DIR}/iso/${INSTALL_DIR}/boot/memtest
    cp ${WORK_DIR}/airootfs/usr/share/licenses/common/GPL2/license.txt ${WORK_DIR}/iso/${INSTALL_DIR}/boot/memtest.COPYING
    cp ${WORK_DIR}/airootfs/boot/intel-ucode.img ${WORK_DIR}/iso/${INSTALL_DIR}/boot/intel_ucode.img
    cp ${WORK_DIR}/airootfs/usr/share/licenses/intel-ucode/LICENSE ${WORK_DIR}/iso/${INSTALL_DIR}/boot/intel_ucode.LICENSE
}

# Prepare /${INSTALL_DIR}/boot/syslinux
make_syslinux() {
	out_action "Set syslinux"
	# le fichier syslinux.cfg et splash.png doit etre cree sous le repertoire $wor_dir/syslinux
    mkdir -p ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux
    for _cfg in ${HOME_PATH}/syslinux/*.cfg; do
        sed "s|%ARCHISO_LABEL%|${ISO_LABEL}|g;
             s|%INSTALL_DIR%|${INSTALL_DIR}|g" ${_cfg} > ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux/${_cfg##*/}
    done
    cp ${HOME_PATH}/syslinux/splash.png ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux
    cp ${WORK_DIR}/airootfs/usr/lib/syslinux/bios/*.c32 ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux
    cp ${WORK_DIR}/airootfs/usr/lib/syslinux/bios/lpxelinux.0 ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux
    cp ${WORK_DIR}/airootfs/usr/lib/syslinux/bios/memdisk ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux
    mkdir -p ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux/hdt
    gzip -c -9 ${WORK_DIR}/airootfs/usr/share/hwdata/pci.ids > ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux/hdt/pciids.gz
    gzip -c -9 ${WORK_DIR}/airootfs/usr/lib/modules/*-ARCH/modules.alias > ${WORK_DIR}/iso/${INSTALL_DIR}/boot/syslinux/hdt/modalias.gz
}

# Prepare /isolinux
make_isolinux() {
	out_action "Set isolinux"
    mkdir -p ${WORK_DIR}/iso/isolinux
    sed "s|%INSTALL_DIR%|${INSTALL_DIR}|g" ${HOME_PATH}/isolinux/isolinux.cfg > ${WORK_DIR}/iso/isolinux/isolinux.cfg
    cp ${WORK_DIR}/airootfs/usr/lib/syslinux/bios/isolinux.bin ${WORK_DIR}/iso/isolinux/
    cp ${WORK_DIR}/airootfs/usr/lib/syslinux/bios/isohdpfx.bin ${WORK_DIR}/iso/isolinux/
    cp ${WORK_DIR}/airootfs/usr/lib/syslinux/bios/ldlinux.c32 ${WORK_DIR}/iso/isolinux/
}
# Prepare /EFI
make_efi() {
	out_action "Prepare efiboot"
    mkdir -p ${WORK_DIR}/iso/EFI/boot
    cp ${WORK_DIR}/airootfs/usr/share/efitools/efi/PreLoader.efi ${WORK_DIR}/iso/EFI/boot/bootx64.efi
    cp ${WORK_DIR}/airootfs/usr/share/efitools/efi/HashTool.efi ${WORK_DIR}/iso/EFI/boot/

    cp ${HOME_PATH}/efiboot/loader/bootx64.efi ${WORK_DIR}/iso/EFI/boot/loader.efi

    mkdir -p ${WORK_DIR}/iso/loader/entries
    cp ${HOME_PATH}/efiboot/loader/loader.conf ${WORK_DIR}/iso/loader/
    cp ${HOME_PATH}/efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${WORK_DIR}/iso/loader/entries/
    cp ${HOME_PATH}/efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${WORK_DIR}/iso/loader/entries/

    sed "s|%ARCHISO_LABEL%|${ISO_LABEL}|g;
         s|%INSTALL_DIR%|${INSTALL_DIR}|g" \
        ${HOME_PATH}/efiboot/loader/entries/archiso-x86_64-usb.conf > ${WORK_DIR}/iso/loader/entries/archiso-x86_64.conf

    # EFI Shell 2.0 for UEFI 2.3+
    curl -o ${WORK_DIR}/iso/EFI/shellx64_v2.efi https://raw.githubusercontent.com/tianocore/edk2/master/ShellBinPkg/UefiShell/X64/Shell.efi
    # EFI Shell 1.0 for non UEFI 2.3+
    curl -o ${WORK_DIR}/iso/EFI/shellx64_v1.efi https://raw.githubusercontent.com/tianocore/edk2/master/EdkShellBinPkg/FullShell/X64/Shell_Full.efi
}

make_prepare() {
	out_action "Creating a list of installed packages on live-enviroment..."
    cp -a -l -f ${WORK_DIR}/airootfs ${WORK_DIR}
    ${MAKE_ISO} pkglist
    out_action "Prepare and compress airootfs"
    ${MAKE_ISO} prepare #${gpg_key:+-g ${gpg_key}}
    #rm -rf ${WORK_DIR}/airootfs
    # rm -rf ${WORK_DIR}/${ARCH}/airootfs (if low space, this helps)
}

# Prepare efiboot.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {
	out_action "Set efiboot"
    mkdir -p ${WORK_DIR}/iso/EFI/archiso
    truncate -s 40M ${WORK_DIR}/iso/EFI/archiso/efiboot.img
    mkfs.vfat -n OBARUN_EFI ${WORK_DIR}/iso/EFI/archiso/efiboot.img

    mkdir -p ${WORK_DIR}/efiboot
    mount ${WORK_DIR}/iso/EFI/archiso/efiboot.img ${WORK_DIR}/efiboot

    mkdir -p ${WORK_DIR}/efiboot/EFI/archiso
    cp ${WORK_DIR}/iso/${INSTALL_DIR}/boot/x86_64/vmlinuz ${WORK_DIR}/efiboot/EFI/archiso/vmlinuz.efi
    cp ${WORK_DIR}/iso/${INSTALL_DIR}/boot/x86_64/archiso.img ${WORK_DIR}/efiboot/EFI/archiso/archiso.img

    cp ${WORK_DIR}/iso/${INSTALL_DIR}/boot/intel_ucode.img ${WORK_DIR}/efiboot/EFI/archiso/intel_ucode.img

    mkdir -p ${WORK_DIR}/efiboot/EFI/boot
    cp ${WORK_DIR}/airootfs/usr/share/efitools/efi/PreLoader.efi ${WORK_DIR}/efiboot/EFI/boot/bootx64.efi
    cp ${WORK_DIR}/airootfs/usr/share/efitools/efi/HashTool.efi ${WORK_DIR}/efiboot/EFI/boot/

    cp ${HOME_PATH}/efiboot/loader/bootx64.efi ${WORK_DIR}/efiboot/EFI/boot/loader.efi

    mkdir -p ${WORK_DIR}/efiboot/loader/entries
    cp ${HOME_PATH}/efiboot/loader/loader.conf ${WORK_DIR}/efiboot/loader/
    cp ${HOME_PATH}/efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${WORK_DIR}/efiboot/loader/entries/
    cp ${HOME_PATH}/efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${WORK_DIR}/efiboot/loader/entries/

    sed "s|%ARCHISO_LABEL%|${ISO_LABEL}|g;
         s|%INSTALL_DIR%|${INSTALL_DIR}|g" \
        ${HOME_PATH}/efiboot/loader/entries/archiso-x86_64-cd.conf > ${WORK_DIR}/efiboot/loader/entries/archiso-x86_64.conf

    cp ${WORK_DIR}/iso/EFI/shellx64_v2.efi ${WORK_DIR}/efiboot/EFI/
    cp ${WORK_DIR}/iso/EFI/shellx64_v1.efi ${WORK_DIR}/efiboot/EFI/

    umount -d ${WORK_DIR}/efiboot
}
# Build ISO
make_iso() {
	out_action "Build the iso"
    ${MAKE_ISO} iso "${ISO_NAME}_x86_64-${ISO_VERSION}.iso"
}

if ! [[ -d ${WORK_DIR} ]]; then
	mkdir -p ${WORK_DIR}
fi

# Make sure gpg key exist in any case
# without it make_extra_packages fail
check_gpg "$GPG_DIR"

# Load modules squashfs, not really necessary....
if ! [[ $(lsmod | grep squashfs) ]]; then
	modprobe squashfs || die " Impossible to load squashfs module" "clean_install"
fi

# if NEWROOT is already mounted, make_rootfs fail to copy on WORK_DIR
# so unmount it
if [[ "$VERBOSE" == "yes" ]]; then
	mount_umount "$NEWROOT" "umount" 
else
	mount_umount "$NEWROOT" "umount" &>/dev/null
fi

run_once make_rootfs

if [[ "$VERBOSE" == "yes" ]]; then
	mount_umount "$WORK_DIR/airootfs" "mount" 
else
	mount_umount "$WORK_DIR/airootfs" "mount" &>/dev/null
fi

run_once make_extra_packages
run_once make_setup_mkinitcpio

if [[ "$VERBOSE" == "yes" ]]; then
	mount_umount "${WORK_DIR}/airootfs" "umount" 
else
	mount_umount "${WORK_DIR}/airootfs" "umount" &>/dev/null
fi

run_once make_boot
run_once make_boot_extra
run_once make_syslinux
run_once make_isolinux
run_once make_efi
run_once make_efiboot
run_once make_prepare
run_once make_iso

out_valid "Iso builded successfully"
