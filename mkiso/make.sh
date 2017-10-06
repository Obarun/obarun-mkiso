#!@BINDIR@/bash
# Copyright (c) 2015-2017 Eric Vidal <eric@obarun.org>
# All rights reserved.
# 
# This file is part of Obarun. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution and at https://github.com/Obarun/obarun-mkiso/LICENSE
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.
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

export LANG=C

_mount_airootfs() {
	trap "_umount_airootfs" EXIT ERR QUIT KILL STOP INT TERM HUP
    mkdir -p "${WORK_DIR}/mnt/airootfs"
    out_action "Mounting '${WORK_DIR}/airootfs.img' on '${WORK_DIR}/mnt/airootfs'"
    mount "${WORK_DIR}/airootfs.img" "${WORK_DIR}/mnt/airootfs"
    
}

_umount_airootfs() {
	out_action "Unmounting '${WORK_DIR}/mnt/airootfs'"
    umount -d "${WORK_DIR}/mnt/airootfs"
    out_valid "Done!"
    rmdir "${WORK_DIR}/mnt/airootfs"
    trap "clean_install" ERR QUIT KILL STOP INT TERM HUP
}

# Cleanup airootfs
_cleanup () {
    out_action "Cleaning up what we can on airootfs..."

    # Delete initcpio image(s)
    if [[ -d "${WORK_DIR}/airootfs/boot" ]]; then
        find "${WORK_DIR}/airootfs/boot" -type f -name '*.img' -delete
    fi
    # Delete kernel(s)
    if [[ -d "${WORK_DIR}/airootfs/boot" ]]; then
        find "${WORK_DIR}/airootfs/boot" -type f -name 'vmlinuz*' -delete
    fi
    # Delete pacman database sync cache files (*.tar.gz)
    if [[ -d "${WORK_DIR}/airootfs/var/lib/pacman" ]]; then
        find "${WORK_DIR}/airootfs/var/lib/pacman" -maxdepth 1 -type f -delete
    fi
    # Delete pacman database sync cache
    if [[ -d "${WORK_DIR}/airootfs/var/lib/pacman/sync" ]]; then
        find "${WORK_DIR}/airootfs/var/lib/pacman/sync" -delete
    fi
    # Delete pacman package cache
    if [[ -d "${WORK_DIR}/airootfs/var/cache/pacman/pkg" ]]; then
        find "${WORK_DIR}/airootfs/var/cache/pacman/pkg" -type f -delete
    fi
    # Delete all log files, keeps empty dirs.
    #if [[ -d "${WORK_DIR}/airootfs/var/log" ]]; then
    #    find "${WORK_DIR}/airootfs/var/log" -type f -delete
    #fi
    # Delete all temporary files and dirs
    if [[ -d "${WORK_DIR}/airootfs/var/tmp" ]]; then
        find "${WORK_DIR}/airootfs/var/tmp" -mindepth 1 -delete
    fi
    if [[ -d "${WORK_DIR}/airootfs/usr/share/man" ]]; then
        find "${WORK_DIR}/airootfs/usr/share/man" -type f -delete
    fi
    if [[ -d "${WORK_DIR}/airootfs/usr/share/doc" ]]; then
        find "${WORK_DIR}/airootfs/usr/share/doc" -type f -delete
    fi
    # Delete package pacman related files.
    find "${WORK_DIR}" \( -name "*.pacnew" -o -name "*.pacsave" -o -name "*.pacorig" \) -delete
    out_valid "Done!"
}

# Makes a ext4 filesystem inside a SquashFS from a source directory.
_mkairootfs_img () {
	out_info "img : $SFS_COMP"
	local _qflag=""
    if [[ ! -e "${WORK_DIR}/airootfs" ]]; then
        die " The path '${WORK_DIR}/airootfs' does not exist" "clean_install"
    fi

    out_action "Creating ext4 image of 32GiB..."
    truncate -s 32G "${WORK_DIR}/airootfs.img"
    if [[ ${VERBOSE} == "yes" ]]; then
        _qflag="-q"
    fi
    mkfs.ext4 ${_qflag} -O ^has_journal,^resize_inode -E lazy_itable_init=0 -m 0 -F "${WORK_DIR}/airootfs.img"
    tune2fs -c 0 -i 0 "${WORK_DIR}/airootfs.img" &> /dev/null
   
	out_valid "Done!"
    
   
    _mount_airootfs
    
    out_action "Copying '${WORK_DIR}/airootfs/' to '${WORK_DIR}/mnt/airootfs/'..."
    cp -aT "${WORK_DIR}/airootfs/" "${WORK_DIR}/mnt/airootfs/"
    out_valid "Done!"
    
    _umount_airootfs
    
    mkdir -p "${WORK_DIR}/iso/${INSTALL_DIR}/${ARCH}"
   
    out_action "Creating SquashFS image, this may take some time..."
    
	if [[ "${}" = "y" ]]; then
        mksquashfs "${WORK_DIR}/airootfs.img" "${WORK_DIR}/iso/${INSTALL_DIR}/${ARCH}/airootfs.sfs" -noappend -comp "${SFS_COMP}" -no-progress &> /dev/null
    else
        mksquashfs "${WORK_DIR}/airootfs.img" "${WORK_DIR}/iso/${INSTALL_DIR}/${ARCH}/airootfs.sfs" -noappend -comp "${SFS_COMP}" -no-progress
    fi
    out_valid "Done!"
    rm ${WORK_DIR}/airootfs.img
}

# Makes a SquashFS filesystem from a source directory.
_mkairootfs_sfs () {
    if [[ ! -e "${WORK_DIR}/airootfs" ]]; then
        die " The path '${WORK_DIR}/airootfs' does not exist" "clean_install"
    fi

    mkdir -p "${WORK_DIR}/iso/${INSTALL_DIR}/${ARCH}"
    out_action "Creating SquashFS image, this may take some time..."
  
    if [[ "${VERBOSE}" = "yes" ]]; then
        mksquashfs "${WORK_DIR}/airootfs" "${WORK_DIR}/iso/${INSTALL_DIR}/${ARCH}/airootfs.sfs" -noappend -comp "${SFS_COMP}" -no-progress &> /dev/null
    else
		mksquashfs "${WORK_DIR}/airootfs" "${WORK_DIR}/iso/${INSTALL_DIR}/${ARCH}/airootfs.sfs" -noappend -comp "${SFS_COMP}" -no-progress
    fi
    
    out_valid "Done!"
}

_mkchecksum () {
    out_action "Creating checksum file for self-test..."
    cd "${WORK_DIR}/iso/${INSTALL_DIR}/${ARCH}"
    md5sum airootfs.sfs > airootfs.md5
    cd ${OLDPWD}
    out_valid "Done!"
}

_mksignature () {
    out_action "Creating signature file..."
    cd "${WORK_DIR}/iso/${INSTALL_DIR}/${ARCH}"
    gpg --detach-sign --default-key ${gpg_key} airootfs.sfs
    cd ${OLDPWD}
    out_valid "Done!"
}

command_pkglist () {
    pacman -Sl -r "${WORK_DIR}/airootfs" --config "${HOME_PATH}/pacman.conf" | \
        awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > \
        "${WORK_DIR}/iso/${INSTALL_DIR}/pkglist.${ARCH}.txt"
    out_valid "Done!"

}

# Create an ISO9660 filesystem from "iso" directory.
command_iso () {
    local _iso_efi_boot_args="" _qflag=""

    if [[ ! -f "${WORK_DIR}/iso/isolinux/isolinux.bin" ]]; then
        die "The file '${WORK_DIR}/iso/isolinux/isolinux.bin' does not exist." "clean_install"
    fi
    if [[ ! -f "${WORK_DIR}/iso/isolinux/isohdpfx.bin" ]]; then
        die " The file '${WORK_DIR}/iso/isolinux/isohdpfx.bin' does not exist." "clean_install"
    fi

    # If exists, add an EFI "El Torito" boot image (FAT filesystem) to ISO-9660 image.
    if [[ -f "${WORK_DIR}/iso/EFI/archiso/efiboot.img" ]]; then
        _iso_efi_boot_args="-eltorito-alt-boot
                            -e EFI/archiso/efiboot.img
                            -no-emul-boot
                            -isohybrid-gpt-basdat"
    fi

    mkdir -p ${OUT_DIR}
    out_action "Creating ISO image..."
    
    if [[ ${VERBOSE} == "yes" ]]; then
        _qflag="-quiet"
    fi

    xorriso -as mkisofs ${_qflag} \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "${ISO_LABEL}" \
        -appid "${ISO_APPLICATION}" \
        -publisher "${ISO_PUBLISHER}" \
        -preparer "prepared by obarun-mkiso" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr ${WORK_DIR}/iso/isolinux/isohdpfx.bin \
        ${_iso_efi_boot_args} \
        -output "${OUT_DIR}/${img_name}" \
        "${WORK_DIR}/iso/"
    out_valid "Done! | $(ls -sh ${OUT_DIR}/${img_name})"
}

# create airootfs.sfs filesystem, and push it in "iso" directory.
command_prepare () {

    _cleanup
    if [[ ${IMAGE_MODE} == "sfs" ]]; then
        _mkairootfs_sfs
    else
        _mkairootfs_img
    fi
    _mkchecksum
    #if [[ ${gpg_key} ]]; then
    #  _mksignature
    #fi
}

command_name="${1}"

case "${command_name}" in
    prepare)
        command_prepare
        ;;
    pkglist)
        command_pkglist
        ;;
    iso)
        img_name="${2}"
        command_iso
        ;;
esac
