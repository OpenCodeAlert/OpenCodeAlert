#!/bin/bash
# OpenRA packaging script for Linux (AppImage)

set -o errexit -o pipefail || exit $?

command -v tar >/dev/null 2>&1 || { echo >&2 "Linux packaging requires tar."; exit 1; }
command -v curl >/dev/null 2>&1 || command -v wget > /dev/null 2>&1 || { echo >&2 "Linux packaging requires curl or wget."; exit 1; }

DEPENDENCIES_TAG="20201222"

if [ $# -lt "1" ] || [ $# -gt "3" ]; then
	echo "Usage: $(basename "$0") version [outputdir] [mods]"
	echo "  mods: comma-separated list of mods to build (default: copilot)"
	echo "        available mods: copilot, ra, cnc, d2k, ts"
	echo "        examples: 'copilot' or 'ra,cnc,d2k' or 'all' for all mods"
	exit 1
fi

# Set the working dir to the location of this script
HERE=$(dirname "$0")
cd "${HERE}"
. ../functions.sh

TAG="$1"
OUTPUTDIR="${2:-.}"
MODS_TO_BUILD="${3:-copilot}"

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

SRCDIR="$(pwd)/../.."
ARTWORK_DIR="$(pwd)/../artwork/"

UPDATE_CHANNEL=""
SUFFIX="-devel"
if [[ ${TAG} == release* ]]; then
	UPDATE_CHANNEL="release"
	SUFFIX=""
elif [[ ${TAG} == playtest* ]]; then
	UPDATE_CHANNEL="playtest"
	SUFFIX="-playtest"
elif [[ ${TAG} == pkgtest* ]]; then
	UPDATE_CHANNEL="pkgtest"
	SUFFIX="-pkgtest"
fi

# 检查并自动创建输出目录
mkdir -p "${OUTPUTDIR}"

# Add native libraries
echo "Downloading appimagetool"
if command -v curl >/dev/null 2>&1; then
	curl -s -L -O https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
else
	wget -cq https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
fi

chmod a+x appimagetool-x86_64.AppImage

echo "Building AppImages for mods: ${MODS_TO_BUILD}"

build_appimage() {
	MOD_ID=${1}
	DISPLAY_NAME=${2}
	DISCORD_ID=${3}
	APPDIR="$(pwd)/${MOD_ID}.appdir"
	APPIMAGE="OpenRA-$(echo "${DISPLAY_NAME}" | sed 's/ /-/g')${SUFFIX}-x86_64.AppImage"

	IS_D2K="False"
	if [ "${MOD_ID}" = "d2k" ]; then
		IS_D2K="True"
	fi

	install_assemblies "${SRCDIR}" "${APPDIR}/usr/lib/openra" "linux-x64" "net6" "True" "True" "${IS_D2K}"
	
	# Install data - for copilot, also include ra mod data
	if [ "${MOD_ID}" = "copilot" ]; then
		echo "Installing copilot mod with ra dependencies"
		install_data "${SRCDIR}" "${APPDIR}/usr/lib/openra" "${MOD_ID}" "ra"
	else
		install_data "${SRCDIR}" "${APPDIR}/usr/lib/openra" "${MOD_ID}"
	fi
	
	set_engine_version "${TAG}" "${APPDIR}/usr/lib/openra"
	set_mod_version "${TAG}" "${APPDIR}/usr/lib/openra/mods/${MOD_ID}/mod.yaml" "${APPDIR}/usr/lib/openra/mods/modcontent/mod.yaml"

	# Add launcher and icons
	sed "s/{MODID}/${MOD_ID}/g" AppRun.in | sed "s/{MODNAME}/${DISPLAY_NAME}/g" > "${APPDIR}/AppRun"
	chmod 0755 "${APPDIR}/AppRun"

	mkdir -p "${APPDIR}/usr/share/applications"
	# Note that the non-discord version of the desktop file is used by the Mod SDK and must be maintained in parallel with the discord version!
	sed "s/{MODID}/${MOD_ID}/g" openra.desktop.discord.in | sed "s/{MODNAME}/${DISPLAY_NAME}/g" | sed "s/{TAG}/${TAG}/g" | sed "s/{DISCORDAPPID}/${DISCORD_ID}/g" > "${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop"
	chmod 0755 "${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop"
	cp "${APPDIR}/usr/share/applications/openra-${MOD_ID}.desktop" "${APPDIR}/openra-${MOD_ID}.desktop"

	mkdir -p "${APPDIR}/usr/share/mime/packages"
	# Note that the non-discord version of the mimeinfo file is used by the Mod SDK and must be maintained in parallel with the discord version!
	sed "s/{MODID}/${MOD_ID}/g" openra-mimeinfo.xml.discord.in | sed "s/{TAG}/${TAG}/g" | sed "s/{DISCORDAPPID}/${DISCORD_ID}/g" > "${APPDIR}/usr/share/mime/packages/openra-${MOD_ID}.xml"
	chmod 0755 "${APPDIR}/usr/share/mime/packages/openra-${MOD_ID}.xml"

	if [ -f "${ARTWORK_DIR}/${MOD_ID}_scalable.svg" ]; then
		install -Dm644 "${ARTWORK_DIR}/${MOD_ID}_scalable.svg" "${APPDIR}/usr/share/icons/hicolor/scalable/apps/openra-${MOD_ID}.svg"
	fi

	for i in 16x16 32x32 48x48 64x64 128x128 256x256 512x512 1024x1024; do
		if [ -f "${ARTWORK_DIR}/${MOD_ID}_${i}.png" ]; then
			install -Dm644 "${ARTWORK_DIR}/${MOD_ID}_${i}.png" "${APPDIR}/usr/share/icons/hicolor/${i}/apps/openra-${MOD_ID}.png"
			install -m644 "${ARTWORK_DIR}/${MOD_ID}_${i}.png" "${APPDIR}/openra-${MOD_ID}.png"
		fi
	done

	mkdir -p "${APPDIR}/usr/bin"
	sed "s/{MODID}/${MOD_ID}/g" openra.appimage.in | sed "s/{TAG}/${TAG}/g" | sed "s/{MODNAME}/${DISPLAY_NAME}/g" > "${APPDIR}/usr/bin/openra-${MOD_ID}"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}"

	sed "s/{MODID}/${MOD_ID}/g" openra-server.appimage.in > "${APPDIR}/usr/bin/openra-${MOD_ID}-server"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}-server"

	sed "s/{MODID}/${MOD_ID}/g" openra-utility.appimage.in > "${APPDIR}/usr/bin/openra-${MOD_ID}-utility"
	chmod 0755 "${APPDIR}/usr/bin/openra-${MOD_ID}-utility"

	install -m 0755 gtk-dialog.py "${APPDIR}/usr/bin/gtk-dialog.py"

	# Embed update metadata if (and only if) compiled on GitHub Actions
	if [ -n "${GITHUB_REPOSITORY}" ]; then
		ARCH=x86_64 ./appimagetool-x86_64.AppImage --no-appstream -u "zsync|https://master.openra.net/appimagecheck.zsync?mod=${MOD_ID}&channel=${UPDATE_CHANNEL}" "${APPDIR}" "${OUTPUTDIR}/${APPIMAGE}"
		zsyncmake -u "https://github.com/${GITHUB_REPOSITORY}/releases/download/${TAG}/${APPIMAGE}" -o "${OUTPUTDIR}/${APPIMAGE}.zsync" "${OUTPUTDIR}/${APPIMAGE}"
	else
		ARCH=x86_64 ./appimagetool-x86_64.AppImage --no-appstream "${APPDIR}" "${OUTPUTDIR}/${APPIMAGE}"
	fi

	rm -rf "${APPDIR}"
}

# Build each requested mod
for MOD_ID in "${MOD_ARRAY[@]}"; do
	if [[ -n "$(get_mod_config "${MOD_ID}")" ]]; then
		IFS='|' read -r MOD_NAME DISCORD_APPID <<< "$(get_mod_config "${MOD_ID}")"
		echo "Building ${MOD_NAME} (${MOD_ID})"
		build_appimage "${MOD_ID}" "${MOD_NAME}" "${DISCORD_APPID}"
	else
		echo "Warning: Unknown mod '${MOD_ID}', skipping"
	fi
done

# Clean up
rm -rf appimagetool-x86_64.AppImage "${BUILTDIR}"

echo "Build complete. AppImages are available in: ${OUTPUTDIR}"
