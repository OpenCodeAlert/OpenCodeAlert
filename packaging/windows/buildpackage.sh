#!/bin/bash
# OpenRA packaging script for Windows

set -o errexit -o pipefail || exit $?

command -v curl >/dev/null 2>&1 || command -v wget > /dev/null 2>&1 || { echo >&2 "Windows packaging requires curl or wget."; exit 1; }
command -v makensis >/dev/null 2>&1 || { echo >&2 "Windows packaging requires makensis."; exit 1; }
command -v convert >/dev/null 2>&1 || { echo >&2 "Windows packaging requires ImageMagick."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo >&2 "Windows packaging requires python 3."; exit 1; }
command -v wine64 >/dev/null 2>&1 || { echo >&2 "Windows packaging requires wine64."; exit 1; }

if [ $# -lt "2" ] || [ $# -gt "4" ]; then
	echo "Usage: $(basename "$0") tag outputdir [mods] [keep-portable]"
	echo "  mods: comma-separated list of mods to build (default: copilot)"
	echo "        available mods: copilot, ra, cnc, d2k, ts"
	echo "        examples: 'copilot' or 'ra,cnc,d2k' or 'all' for all mods"
	echo "  keep-portable: if set to 'true', keep portable zip files after creating installers (default: false)"
	exit 1
fi

# Set the working dir to the location of this script
HERE=$(dirname "$0")
cd "${HERE}"
. ../functions.sh

TAG="$1"
OUTPUTDIR="$2"
MODS_TO_BUILD="${3:-copilot}"
KEEP_PORTABLE="${4:-false}"
SRCDIR="$(pwd)/../.."
BUILTDIR="$(pwd)/build"
ARTWORK_DIR="$(pwd)/../artwork/"

FAQ_URL="https://wiki.openra.net/FAQ"

SUFFIX=" (dev)"
if [[ ${TAG} == release* ]]; then
	SUFFIX=""
elif [[ ${TAG} == playtest* ]]; then
	SUFFIX=" (playtest)"
fi

# Define available mods (using regular arrays for compatibility with older bash)
MOD_IDS=("copilot" "ra" "cnc" "d2k" "ts")
MOD_NAMES=("Copilot" "Red Alert" "Tiberian Dawn" "Dune 2000" "Tiberian Sun")
MOD_DISCORD_IDS=("699222659766026240" "699222659766026240" "699223250181292033" "712711732770111550" "000000000000000000")

# Parse mods to build
if [ "${MODS_TO_BUILD}" = "all" ]; then
	MODS_TO_BUILD="copilot,ra,cnc,d2k,ts"
fi

IFS=',' read -ra MOD_ARRAY <<< "${MODS_TO_BUILD}"

# Function to get mod config by ID
get_mod_config() {
	local mod_id="$1"
	for i in "${!MOD_IDS[@]}"; do
		if [ "${MOD_IDS[$i]}" = "${mod_id}" ]; then
			echo "${MOD_NAMES[$i]}|${MOD_DISCORD_IDS[$i]}"
			return 0
		fi
	done
	echo ""
}

if command -v curl >/dev/null 2>&1; then
	curl -s -L -O https://github.com/electron/rcedit/releases/download/v1.1.1/rcedit-x64.exe
else
	wget -cq https://github.com/electron/rcedit/releases/download/v1.1.1/rcedit-x64.exe
fi

function makelauncher()
{
	LAUNCHER_NAME="${1}"
	DISPLAY_NAME="${2}"
	MOD_ID="${3}"
	PLATFORM="${4}"

	TAG_TYPE="${TAG%%-*}"
	TAG_VERSION="${TAG#*-}"
	BACKWARDS_TAG="${TAG_VERSION}-${TAG_TYPE}"

	# Function to copy icon with fallback to default
	copy_icon_with_fallback() {
		local mod_id="$1"
		local target="$2"
		local mod_icon="${ARTWORK_DIR}/${mod_id}_${target}.png"
		local default_icon="${ARTWORK_DIR}/ra_${target}.png"
		
		if [ -f "${mod_icon}" ]; then
			echo "${mod_icon}"
		elif [ -f "${default_icon}" ]; then
			echo "Warning: ${mod_icon} not found, using default icon"
			echo "${default_icon}"
		else
			echo "Error: Neither ${mod_icon} nor ${default_icon} found"
			exit 1
		fi
	}
	
	# Get icon files with fallback
	ICON_16=$(copy_icon_with_fallback "${MOD_ID}" "16x16")
	ICON_24=$(copy_icon_with_fallback "${MOD_ID}" "24x24")
	ICON_32=$(copy_icon_with_fallback "${MOD_ID}" "32x32")
	ICON_48=$(copy_icon_with_fallback "${MOD_ID}" "48x48")
	ICON_256=$(copy_icon_with_fallback "${MOD_ID}" "256x256")
	
	convert "${ICON_16}" "${ICON_24}" "${ICON_32}" "${ICON_48}" "${ICON_256}" "${BUILTDIR}/${MOD_ID}.ico"
	install_windows_launcher "${SRCDIR}" "${BUILTDIR}" "win-${PLATFORM}" "${MOD_ID}" "${LAUNCHER_NAME}" "${DISPLAY_NAME}" "${FAQ_URL}" "${TAG}"

	# Use rcedit to patch the generated EXE with missing assembly/PortableExecutable information because .NET 6 ignores that when building on Linux.
	# Using a backwards version tag because rcedit is unable to set versions starting with a letter.
	wine64 rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-product-version "${BACKWARDS_TAG}"
	wine64 rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "ProductName" "OpenRA"
	wine64 rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "CompanyName" "The OpenRA team"
	wine64 rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "FileDescription" "${LAUNCHER_NAME} mod for OpenRA"
	wine64 rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-version-string "LegalCopyright" "Copyright (c) The OpenRA Developers and Contributors"
	wine64 rcedit-x64.exe "${BUILTDIR}/${LAUNCHER_NAME}.exe" --set-icon "${BUILTDIR}/${MOD_ID}.ico"
}

function build_platform()
{
	PLATFORM="${1}"

	echo "Building core files (${PLATFORM})"
	if [ "${PLATFORM}" = "x86" ]; then
		USE_PROGRAMFILES32="-DUSE_PROGRAMFILES32=true"
	else
		USE_PROGRAMFILES32=""
	fi

	# Install assemblies for all mods
	install_assemblies "${SRCDIR}" "${BUILTDIR}" "win-${PLATFORM}" "net6" "False" "True" "True"
	
	# Install data for requested mods
	for MOD_ID in "${MOD_ARRAY[@]}"; do
		if [[ -n "$(get_mod_config "${MOD_ID}")" ]]; then
			IFS='|' read -r MOD_NAME DISCORD_APPID <<< "$(get_mod_config "${MOD_ID}")"
			echo "Installing data for ${MOD_NAME} (${MOD_ID})"
			
			# For copilot, also include ra mod data
			if [ "${MOD_ID}" = "copilot" ]; then
				echo "Installing copilot mod with ra dependencies"
				install_data "${SRCDIR}" "${BUILTDIR}" "${MOD_ID}" "ra"
			else
				install_data "${SRCDIR}" "${BUILTDIR}" "${MOD_ID}"
			fi
		fi
	done
	
	set_engine_version "${TAG}" "${BUILTDIR}"
	
	# Set mod versions for all installed mods
	for MOD_ID in "${MOD_ARRAY[@]}"; do
		if [[ -n "$(get_mod_config "${MOD_ID}")" ]]; then
			if [ -f "${BUILTDIR}/mods/${MOD_ID}/mod.yaml" ]; then
				set_mod_version "${TAG}" "${BUILTDIR}/mods/${MOD_ID}/mod.yaml" "${BUILTDIR}/mods/modcontent/mod.yaml"
			fi
		fi
	done

	echo "Compiling Windows launchers (${PLATFORM})"
	for MOD_ID in "${MOD_ARRAY[@]}"; do
		if [[ -n "$(get_mod_config "${MOD_ID}")" ]]; then
			IFS='|' read -r MOD_NAME DISCORD_APPID <<< "$(get_mod_config "${MOD_ID}")"
			echo "Building launcher for ${MOD_NAME} (${MOD_ID})"
			
			# Generate launcher name from mod name
			LAUNCHER_NAME=$(echo "${MOD_NAME}" | sed 's/ //g')
			makelauncher "${LAUNCHER_NAME}" "${MOD_NAME}" "${MOD_ID}" "${PLATFORM}"
		fi
	done

	echo "Building Windows setup.exe (${PLATFORM})"
	makensis -V2 -DSRCDIR="${BUILTDIR}" -DTAG="${TAG}" -DSUFFIX="${SUFFIX}" -DOUTFILE="${OUTPUTDIR}/OpenRA-${TAG}-${PLATFORM}.exe" ${USE_PROGRAMFILES32} OpenRA-dynamic.nsi

	echo "Packaging zip archive (${PLATFORM})"
	pushd "${BUILTDIR}" > /dev/null
	zip "OpenRA-${TAG}-${PLATFORM}-winportable.zip" -r -9 ./* --quiet
	mv "OpenRA-${TAG}-${PLATFORM}-winportable.zip" "${OUTPUTDIR}"
	popd > /dev/null

	rm -rf "${BUILTDIR}"
}

echo "Building launchers for mods: ${MODS_TO_BUILD}"

# Build for both platforms
build_platform "x86"
build_platform "x64"

# Remove portable zip files if not keeping them
if [ "${KEEP_PORTABLE}" != "true" ]; then
	echo "Removing portable zip files (installers created successfully)"
	rm -f "${OUTPUTDIR}/OpenRA-${TAG}-x86-winportable.zip"
	rm -f "${OUTPUTDIR}/OpenRA-${TAG}-x64-winportable.zip"
else
	echo "Keeping portable zip files as requested"
fi

rm rcedit-x64.exe

echo "Build complete. Installers are available in: ${OUTPUTDIR}"
# changeCR2LF