#!/usr/bin/bash

# {{{ From /usr/share/makepkg/util/message.sh

colorize() {
	# prefer terminal safe colored and bold text when tput is supported
	if tput setaf 0 &>/dev/null; then
		ALL_OFF="$(tput sgr0)"
		BOLD="$(tput bold)"
		BLUE="${BOLD}$(tput setaf 4)"
		GREEN="${BOLD}$(tput setaf 2)"
		RED="${BOLD}$(tput setaf 1)"
		YELLOW="${BOLD}$(tput setaf 3)"
	else
		ALL_OFF="\e[0m"
		BOLD="\e[1m"
		BLUE="${BOLD}\e[34m"
		GREEN="${BOLD}\e[32m"
		RED="${BOLD}\e[31m"
		YELLOW="${BOLD}\e[33m"
	fi
	readonly ALL_OFF BOLD BLUE GREEN RED YELLOW
}

# plainerr/plainerr are primarily used to continue a previous message on a new
# line, depending on whether the first line is a regular message or an error
# output

plain() {
	(( QUIET )) && return
	local mesg=$1; shift
	printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@"
}

plainerr() {
	plain "$@" >&2
}

msg() {
	(( QUIET )) && return
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

msg2() {
	(( QUIET )) && return
	local mesg=$1; shift
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

ask() {
	local mesg=$1; shift
	printf "${BLUE}::${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}" "$@"
}

warning() {
	local mesg=$1; shift
	printf "${YELLOW}==> $(gettext "WARNING:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
	local mesg=$1; shift
	printf "${RED}==> $(gettext "ERROR:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

# }}}

rexit(){ # clear any input, then exit on any new keypress
	((ret=${1:-$?}))
	read -r -d '' -t 1
	ask '(Press any key to exit.)'
	read -r -N 1
	exit "$ret"
}

# {{{ Emulator Config
config_base(){ # {{{ [name] [backup] [src] [dest]
	# $1: human-readable name for terminal output
	# $2: Containing directory/file to back up
	# $3: Source of directory/file to copy
	# $4: Destination of directory/file to copy
	#     (Falls back to $2 if not provided)
	if ! [[ -d $2.bak ]]; then
		msg 'Backing up %s.' "$1"
		cp -r "$2"{,.bak}
	fi
	rsync -avP "$3" "${4:-$2}"
} # }}}
config_retroarch(){ #{{{
	local corePath=$1/config/retroarch/cores
	local url=https://buildbot.libretro.com/nightly/linux/x86_64/latest/
	local coreName coreFile
	mkdir -p "$corePath"
	msg2 'RetroArch: Downloading Cores...'
	for coreName in \
		bsnes_hd_beta \
		fbneo \
		flycast \
		gambatte \
		genesis_plus_gx \
		genesis_plus_gx_wide \
		mame2003_plus \
		mednafen_lynx \
		mednafen_ngp \
		mednafen_wswan \
		melonds \
		mesen \
		mgba \
		mupen64plus_next \
		nestopia \
		picodrive \
		ppsspp \
		snes9x \
		stella \
		yabasanshiro \
		yabause
	do
		coreFile=${coreName}_libretro.so
		if [[ -f $corePath/$coreFile ]]; then
			plain '%s already downloaded!' "$coreName"
		elif
			msg2 '%s not found, downloading...' "$coreName"
			curl -s "$url$coreFile.zip" --output "$corePath/$coreFile.zip"
		then
			plain '%s downloaded!' "$coreName"
			unzip -o "$corePath/$coreFile" -d "$corePath"
			rm -f "$corePath/$coreFile"
		else
			error 'Could not download %s!' "$coreName"
		fi
	done

	local configFile=$1/config/retroarch/retroarch.cfg
	if [[ -f $configFile.bak ]]; then
		msg2 'RetroArch config file is already backed up, skipping.'
	else
		cp "$configFile"{,.bak}
		msg2 'Backed up RetroArch config file.'
	fi
	mkdir -p "$1/config/retroarch/overlays"
	rsync -r "$tmpdir/EmuDeck/configs/org.libretro.RetroArch/config/retroarch/overlays" \
		"$1/config/retroarch/overlays"
	rsync -r "$tmpdir/EmuDeck/configs/org.libretro.RetroArch/config/retroarch/config" \
		"$1/config/retroarch/config"

	msg2 'Patching RetroArch config file...'
	sed -i '
		s/config_save_on_exit = "true"/config_save_on_exit = "false"/g
		s/input_overlay_enable = "true"/input_overlay_enable = "false"/g
		s/menu_show_load_content_animation = "true"/menu_show_load_content_animation = "false"/g
		s/notification_show_autoconfig = "true"/notification_show_autoconfig = "false"/g
		s/notification_show_config_override_load = "true"/notification_show_config_override_load = "false"/g
		s/notification_show_refresh_rate = "true"/notification_show_refresh_rate = "false"/g
		s/notification_show_remap_load = "true"/notification_show_remap_load = "false"/g
		s/notification_show_screenshot = "true"/notification_show_screenshot = "false"/g
		s/notification_show_set_initial_disk = "true"/notification_show_set_initial_disk = "false"/g
		s/notification_show_patch_applied = "true"/notification_show_patch_applied = "false"/g
		s/menu_swap_ok_cancel_buttons = "false"/menu_swap_ok_cancel_buttons = "true"/g
		s/savestate_auto_save = "false"/savestate_auto_save = "true"/g
		s/savestate_auto_load = "false"/savestate_auto_load = "true"/g
		s/video_fullscreen = "false"/video_fullscreen = "true"/g
		s/video_shader_enable = "false"/video_shader_enable = "true"/g

		s/input_enable_hotkey_btn = "nul"/input_enable_hotkey_btn = "4"/g
		s/input_fps_toggle_btn = "nul"/input_fps_toggle_btn = "3"/g
		s/input_load_state_btn = "nul"/input_load_state_btn = "9"/g
		s/input_rewind_axis = "nul"/input_rewind_axis = "+4"/g
		s/input_save_state_btn = "nul"/input_save_state_btn = "10"/g
		s/input_menu_toggle_gamepad_combo = "nul"/input_menu_toggle_gamepad_combo = "2"/g
		s/input_hold_fast_forward_axis = "nul"/input_hold_fast_forward_axis = "+5"/g
		s/input_quit_gamepad_combo = "0"/input_quit_gamepad_combo = "4"/g
		s/input_pause_toggle_btn = "nul"/input_pause_toggle_btn = "0"/g
		s:system_directory = "[^"]*":system_directory = "'"$biosPath"'":g
	' "$configFile"
} # }}}
config_dolphin(){ # {{{
	config_base Dolphin "$1/config" "$tmpdir/configs/org.DolphinEmu.dolphin-emu/" "$1/"
} # }}}
config_pcsx2(){ # {{{
	: # Work in progress
	# config_base PCSX2 "$1/config" "$tmpdir/configs/net.pcsx2.PCSX2/" "$1/"
} # }}}
config_rpcs3(){ # {{{
	config_base RPCS3 "$1/config" "$tmpdir/configs/net.rpcs3.RPCS3/" "$1/"
} # }}}
config_yuzu(){ # {{{
	config_base Yuzu "$1/config" "$tmpdir/configs/org.yuzu_emu.yuzu/" "$1/"
} # }}}
config_citra(){ # {{{
	config_base Citra "$1/config" "$tmpdir/configs/org.citra_emu.citra/" "$1/"
} # }}}
config_ds(){ # {{{
	config_base DuckStation "$1/data" "$tmpdir/configs/org.duckstation.DuckStation/" "$1/"
	sed -i "s:/run/media/mmcblk0p1/Emulation/bios/:$biosPath:g" "$1/data/duckstation/settings.ini"
} # }}}
# }}}

[[ -t 1 ]] && colorize

case $1 in
	SD)
		media=(/run/media/mm*)
		if (( ${#media[@]} )) || {
			udiskctl mount -b /dev/mmcblk0p1
			media=(/run/media/mm*)
			(( ${#media[@]} ))
		}; then
			romsPath=${media[0]}/Emulation/roms/
			biosPath=${media[0]}/Emulation/bios/
		else
			error 'Could not find your SD card!'
			rexit 1
		fi
		;;
	'')
		romsPath=$HOME/Emulation/roms
		biosPath=$HOME/Emulation/bios
		;;
	*)
		p=$(realpath "$1")
		romsPath=$p/roms
		biosPath=$p/bios
esac

cleanup(){
	rm -rf "$tmpdir" && trap - EXIT INT TERM
	exit
}
trap cleanup EXIT INT TERM
tmpdir=$(mktemp -d)
if ! cd "$tmpdir"; then
	error 'Could not create a temporary directory for EmuDeck!'
	rexit 1
fi

msg 'Pulling the latest files...'
if ! git clone https://github.com/xPMo/EmuDeck.git EmuDeck &> /dev/null; then
	error 'Could not download files! Are you connected to the internet?'
	rexit 1
fi

cat EmuDeck/logo.ans
msg2 "EmuDeck %s" "$(cat EmuDeck/version.md)"

msg 'Configuring Steam ROM Manager...'
mkdir -p "$romsPath" "$biosPath" "$HOME/.config/steam-rom-manager/userData"
cp "$tmpdir/EmuDeck/configs/steam-rom-manager/userData/userConfigurations.json" "$HOME/.config/steam-rom-manager/userData/userConfigurations.json"
sed -i "s:/run/media/mmcblk0p1/Emulation/roms/:$romsPath:g" "$HOME/.config/steam-rom-manager/userData/userConfigurations.json"

typeset -A emu_locations=(
	[RetroArch]=$HOME/.var/app/org.libretro.RetroArch
	[Dolphin]=$HOME/.var/app/org.DolphinEmu.dolphin-emu
	[PCSX2]=$HOME/.var/app/net.pcsx2.PCSX2
	[RPCS3]=$HOME/.var/app/net.rpcs3.RPCS3
	[Yuzu]=$HOME/.var/app/org.yuzu_emu.yuzu
	[Citra]=$HOME/.var/app/org.citra_emu.citra
	[DuckStation]=$HOME/.var/app/org.duckstation.DuckStation
)
found_emus=()
msg 'Checking installed emulators...'
for emu in "${!emu_locations[@]}"; do
	if [[ -d ${emu_locations[$emu]} ]]; then
		msg 'Found %s.' "$emu"
		found_emus+=("$emu")
	else
		warning 'Could not find %s.' "$emu"
		plain 'Install and launch %s from Discover if you want to configure it.' "$emu"
	fi
done

msg2 'Configuring emulators...'
for emu in "${found_emus[@]}"; do
	emu=${emu,,}
	emu=${emu// }
	"config_$emu" "${emu_locations[$emu]}"
done

msg 'Done!'
plain ''

rm -rf "$tmpdir" && trap - EXIT INT TERM
msg2 'Cleaning up downloaded files.'

msg2 'Now to add your games copy them to this exact folder within the appropriate subfolder for each system:'
plain '%s' '' "$romsPath" ''
msg2 'Copy your BIOS to this folder:'
plain '%s' '' "$biosPath" ''
msg2 'When you are done copying your ROMs and BIOS, do the following:'
plain '%s' \
	'1: Right Click the Steam Icon in the taskbar and close it. If you are using the integrated trackpads, the left mouse button is now the R2 and the right mouse button is the L1 button' \
	'2: Open Steam Rom Manager' \
	'3: On Steam Rom Manager click on Preview' \
	'4: Now click on Generate app list' \
	'5: Wait for the images to finish (Marked as remaining providers on the top)' \
	'6: Click Save app list' \
	'7: Close Steam Rom Manager and this window and click on Return to Gaming Mode.' \
	'8: Enjoy!'
rexit

# vim:foldmethod=marker
