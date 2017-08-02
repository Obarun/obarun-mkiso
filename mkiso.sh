#!/usr/bin/bash
#
# Authors:
# Eric Vidal <eric@obarun.org>
#
# Copyright (C) 2015-2017 Eric Vidal <eric@obarun.org>
#
## This script is under license BEER-WARE.
# "THE BEER-WARE LICENSE" (Revision 42):
# <eric@obarun.org> wrote this file.  As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.   Eric Vidal

# functions file for obarun-mkiso package

## 		Some global variables needed

HOME_PATH="/var/lib/obarun/obarun-mkiso"
MAKE_ISO="/usr/lib/obarun/make_iso"
BUILD_ISO="/usr/lib/obarun/build_iso"
WORK_DIR="${HOME_PATH}/work"
ARCH=$(uname -m)
PKG_LIST=""


clean_install(){
	
	out_action "Cleaning up"
	if [[ $(mount | grep "$NEWROOT"/proc) ]]; then
		out_valid "Umount $NEWROOT"
		mount_umount "$NEWROOT" "umount"
	fi
	if [[ $(mount | grep "$WORK_DIR/airootfs/proc") ]]; then
		out_valid "Umount $WORK_DIR/airootfs"
		mount_umount "$WORK_DIR/airootfs" "umount"
	fi
	if [[ $(awk -F':' '{ print $1}' /etc/passwd | grep usertmp) >/dev/null ]]; then
		out_valid "Removing user usertmp"
		user_del "usertmp" &>/dev/null
	fi
	
	out_valid "Restore your shell options"
	shellopts_restore

	exit
}

define_iso_variable(){
	local msg variable set
	msg="$1"
	variable="$2"
	
	out_action "Enter the $msg"
	read -e set
	
	while [[ -z $set ]]; do
		out_notvalid "Empty value, please retry"
		read set
	done
	
	case $variable in
		ISO_NAME)
			ISO_NAME="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,ISO_NAME=.*$,ISO_NAME=\"${set}\",g" /etc/obarun/mkiso.conf;;
		ISO_VERSION)
			ISO_VERSION="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,ISO_VERSION=.*$,ISO_VERSION=\"${set}\",g" /etc/obarun/mkiso.conf;;
		ISO_LABEL)
			ISO_LABEL="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,ISO_LABEL=.*$,ISO_LABEL=\"${set}\",g" /etc/obarun/mkiso.conf;;
		ISO_PUBLISHER)
			ISO_PUBLISHER="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,ISO_PUBLISHER=.*$,ISO_PUBLISHER=\"${set}\",g" /etc/obarun/mkiso.conf;;
		ISO_APPLICATION)
			ISO_APPLICATION="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,ISO_APPLICATION=.*$,ISO_APPLICATION=\"${set}\",g" /etc/obarun/mkiso.conf;;
		INSTALL_DIR)
			INSTALL_DIR="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,INSTALL_DIR=.*$,INSTALL_DIR=\"${set}\",g" /etc/obarun/mkiso.conf;;
		OUT_DIR)
			OUT_DIR="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,OUT_DIR=.*$,OUT_DIR=\"${set}\",g" /etc/obarun/mkiso.conf;;
		IMAGE_MODE)
			while [[ $set != @(img|sfs) ]]; do
				out_notvalid "sfs_mode must be img or sfs, please retry"
				read set
			done
			IMAGE_MODE="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,IMAGE_MODE=.*$,IMAGE_MODE=\"${set}\",g" /etc/obarun/mkiso.conf;;
		SFS_COMP)
			while [[ $set != @(gzip|lzma|lzo|xz) ]]; do
				out_notvalid "sfs_comp must be gzip or lzma or lzo or xz, please retry"
				read set
			done
			SFS_COMP="${set}"
			out_valid "${msg} is now : $set"
			sed -i "s,SFS_COMP=.*$,SFS_COMP=\"${set}\",g" /etc/obarun/mkiso.conf;;
		VERBOSE)
			reply_answer
			if (( ! $? )); then
				VERBOSE="yes"
				out_valid "Verbose enabled"
				sed -i "s,VERBOSE=.*$,VERBOSE=\"yes\",g" /etc/obarun/mkiso.conf
			else
				VERBOSE="no"
				out_notvalid "Verbose disabled"
				sed -i "s,VERBOSE=.*$,VERBOSE=\"no\",g" /etc/obarun/mkiso.conf
			fi;;
	esac
}

start_build(){
		
	check_mountpoint "$NEWROOT"
	
	if (( $? )); then
		out_notvalid "This is not a valid mountpoint"
		die " You need to mount a device on $NEWROOT or choose another directory" "clean_install"
	fi
	
	${BUILD_ISO}
}

clean_work_dir(){
	if [[ -d $WORK_DIR ]]; then
		out_action "Removing $WORK_DIR"
		rm -R "$WORK_DIR"
	else
		out_action "$WORK_DIR doesn't exist"
	fi
}

## 		Select root directory

choose_rootdir(){	
	local _directory
		
	out_action "Enter your root directory :"
	read -e _directory
		
	until [[ -d "$_directory" ]]; do
		out_notvalid "This is not a directory, please retry :"
		read -e _directory
	done
	
	while ! mountpoint -q "$_directory"; do
		out_notvalid "This is not a valide mountpoint, please retry :"
		read -e _directory
	done

	out_valid "Your root directory for installation is now : $_directory"
	#NEWROOT="${_directory}"
	sed -i "s,NEWROOT=.*$,NEWROOT=\"${_directory}\",g" /etc/obarun/mkiso.conf
	
	unset _directory
}

main_menu(){
	
	local step=100

while [[ "$step" !=  15 ]]; do
	source /etc/obarun/mkiso.conf
	clear
	out_void
	out_void
	out_menu_title "**************************************************************"
	out_menu_title "                       Iso menu"
	out_menu_title "**************************************************************"
	out_void
	out_menu_list " 1  -  Choose directory to copy on iso ${green}[$NEWROOT]"
	out_menu_list " 2  -  Set iso name ${green}[$ISO_NAME]"
	out_menu_list " 3  -  Set iso version ${green}[$ISO_VERSION]"
	out_menu_list " 4  -  Set iso label ${green}[$ISO_LABEL]"
	out_menu_list " 5  -  Set iso publisher ${green}[$ISO_PUBLISHER]"
	out_menu_list " 6  -  Set application name for the iso ${green}[$ISO_APPLICATION]"
	out_menu_list " 7  -  Set installation directory inside iso ${green}[$INSTALL_DIR]"
	out_menu_list " 8  -  Set directory where the iso is saved ${green}[$OUT_DIR]"
	out_menu_list " 9  -  Set SquashFS image mode (img or sfs) ${green}[$IMAGE_MODE]"
	out_menu_list " 10 -  Set SquashFS compression type (gzip, lzma, lzo, xz) ${green}[$SFS_COMP]"
	out_void
	out_menu_list " 11 -  Start building"
	out_void
	out_menu_title "**************************************************************"
	out_menu_title "                      Expert mode"
	out_menu_title "**************************************************************"
	out_void
	out_menu_list " 12 -  Enable verbose ${green}[$VERBOSE]"
	out_menu_list " 13 -  Clean the working directory ${green}[$WORK_DIR]"
	out_menu_list " 14 -  Take a coffee"
	out_void
	out_void
	out_menu_list " ${red}15  -  Exit from mkiso script"
	out_void
	out_void
	out_menu_list " Enter your choice :";read  step

		case "$step" in 
			1)	choose_rootdir;;
			2)	define_iso_variable "iso name" "ISO_NAME";; 
			3)	define_iso_variable "iso version" "ISO_VERSION";; 
			4)	define_iso_variable "iso label" "ISO_LABEL";; 
			5)	define_iso_variable "iso publisher" "ISO_PUBLISHER";; 
			6)	define_iso_variable "application name" "ISO_APPLICATION";;
			7)	define_iso_variable "installation directory" "INSTALL_DIR";; 
			8)	define_iso_variable "output directory" "OUT_DIR";; 
			9)	define_iso_variable "image mode [img|sfs]" "IMAGE_MODE";; 
			10)	define_iso_variable "compression type [gzip|lzma|lzo|xz]" "SFS_COMP";; 
			11)	out_action "Start building iso"
				start_build
				exit;;
			12) define_iso_variable "option for verbosity [y|n]" "VERBOSE";;	
			13) clean_work_dir;;
			14) out_info "Under development, not available";;
			15)	exit;;
			*) out_notvalid "Invalid number, please retry:"
		esac
		out_info "Press enter to return to the iso menu"
		read enter 
done
}

