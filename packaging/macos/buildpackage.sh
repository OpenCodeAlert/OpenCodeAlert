#!/bin/bash
# OpenRA packaging script for macOS
#
# The application bundles will be signed if the following environment variables are defined:
#   MACOS_DEVELOPER_IDENTITY: The alphanumeric identifier listed in the certificate name ("Developer ID Application: <your name> (<identity>)")
#                             or as Team ID in your Apple Developer account Membership Details.
# If the identity is not already in the default keychain, specify the following environment variables to import it:
#   MACOS_DEVELOPER_CERTIFICATE_BASE64: base64 content of the exported .p12 developer ID certificate.
#                                       Generate using `base64 certificate.p12 | pbcopy`
#   MACOS_DEVELOPER_CERTIFICATE_PASSWORD: password to unlock the MACOS_DEVELOPER_CERTIFICATE_BASE64 certificate
#
# The applicaton bundles will be notarized if the following environment variables are defined:
#   MACOS_DEVELOPER_USERNAME: Email address for the developer account
#   MACOS_DEVELOPER_PASSWORD: App-specific password for the developer account
#

set -o errexit -o pipefail || exit $?

if [[ "${OSTYPE}" != "darwin"* ]]; then
	echo >&2 "macOS packaging requires a macOS host"
	exit 1
fi

command -v clang >/dev/null 2>&1 || { echo >&2 "macOS packaging requires clang."; exit 1; }

if [ $# -lt "2" ] || [ $# -gt "4" ]; then
	echo "Usage: $(basename "$0") tag outputdir [mods] [keep-apps]"
	echo "  mods: comma-separated list of mods to build (default: copilot)"
	echo "        available mods: copilot, ra, cnc, d2k, ts"
	echo "        examples: 'copilot' or 'ra,cnc,d2k' or 'all' for all mods"
	echo "  keep-apps: if set to 'true', keep .app files after creating DMG (default: false)"
	exit 1
fi

# Set the working dir to the location of this script
HERE=$(dirname "${0}")
cd "${HERE}"
. ../functions.sh

# Import code signing certificate
if [ -n "${MACOS_DEVELOPER_CERTIFICATE_BASE64}" ] && [ -n "${MACOS_DEVELOPER_CERTIFICATE_PASSWORD}" ] && [ -n "${MACOS_DEVELOPER_IDENTITY}" ]; then
	echo "Importing signing certificate"
	echo "${MACOS_DEVELOPER_CERTIFICATE_BASE64}" | base64 --decode > build.p12
	security create-keychain -p build build.keychain
	security default-keychain -s build.keychain
	security unlock-keychain -p build build.keychain
	security import build.p12 -k build.keychain -P "${MACOS_DEVELOPER_CERTIFICATE_PASSWORD}" -T /usr/bin/codesign >/dev/null 2>&1
	security set-key-partition-list -S apple-tool:,apple: -s -k build build.keychain >/dev/null 2>&1
	rm -fr build.p12
fi

TAG="${1}"
OUTPUTDIR="${2}"
MODS_TO_BUILD="${3:-copilot}"
KEEP_APPS="${4:-false}"

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
BUILTDIR="$(pwd)/build"
ARTWORK_DIR="$(pwd)/../artwork/"

modify_plist() {
	sed "s|${1}|${2}|g" "${3}" > "${3}.tmp" && mv "${3}.tmp" "${3}"
}

# Copies the game files and sets metadata
build_app() {
	TEMPLATE_DIR="${1}"
	LAUNCHER_DIR="${2}"
	MOD_ID="${3}"
	MOD_NAME="${4}"
	DISCORD_APPID="${5}"

	LAUNCHER_CONTENTS_DIR="${LAUNCHER_DIR}/Contents"
	LAUNCHER_RESOURCES_DIR="${LAUNCHER_CONTENTS_DIR}/Resources"

	cp -r "${TEMPLATE_DIR}" "${LAUNCHER_DIR}"

	IS_D2K="False"
	if [ "${MOD_ID}" = "d2k" ]; then
		IS_D2K="True"
	fi

	# Install engine and mod files
	install_assemblies "${SRCDIR}" "${LAUNCHER_CONTENTS_DIR}/MacOS/x86_64" "osx-x64" "net6" "True" "True" "${IS_D2K}"
	install_assemblies "${SRCDIR}" "${LAUNCHER_CONTENTS_DIR}/MacOS/arm64" "osx-arm64" "net6" "True" "True" "${IS_D2K}"
	install_assemblies "${SRCDIR}" "${LAUNCHER_CONTENTS_DIR}/MacOS/mono" "osx-x64" "mono" "True" "True" "${IS_D2K}"

	# Install data - for copilot, also include ra mod data
	if [ "${MOD_ID}" = "copilot" ]; then
		echo "Installing copilot mod with ra dependencies"
		install_data "${SRCDIR}" "${LAUNCHER_RESOURCES_DIR}" "${MOD_ID}" "ra"
	else
		install_data "${SRCDIR}" "${LAUNCHER_RESOURCES_DIR}" "${MOD_ID}"
	fi
	
	set_engine_version "${TAG}" "${LAUNCHER_RESOURCES_DIR}"
	set_mod_version "${TAG}" "${LAUNCHER_RESOURCES_DIR}/mods/${MOD_ID}/mod.yaml" "${LAUNCHER_RESOURCES_DIR}/mods/modcontent/mod.yaml"

	# Assemble multi-resolution icon
	mkdir "${MOD_ID}.iconset"
	
	# Function to copy icon with fallback to default
	copy_icon_with_fallback() {
		local size="$1"
		local target="$2"
		local mod_icon="${ARTWORK_DIR}/${MOD_ID}_${size}.png"
		local default_icon="${ARTWORK_DIR}/ra_${size}.png"
		
		if [ -f "${mod_icon}" ]; then
			cp "${mod_icon}" "${MOD_ID}.iconset/${target}"
		elif [ -f "${default_icon}" ]; then
			echo "Warning: ${mod_icon} not found, using default icon"
			cp "${default_icon}" "${MOD_ID}.iconset/${target}"
		else
			echo "Error: Neither ${mod_icon} nor ${default_icon} found"
			exit 1
		fi
	}
	
	copy_icon_with_fallback "16x16" "icon_16x16.png"
	copy_icon_with_fallback "32x32" "icon_16x16@2.png"
	copy_icon_with_fallback "32x32" "icon_32x32.png"
	copy_icon_with_fallback "64x64" "icon_32x32@2x.png"
	copy_icon_with_fallback "128x128" "icon_128x128.png"
	copy_icon_with_fallback "256x256" "icon_128x128@2x.png"
	copy_icon_with_fallback "256x256" "icon_256x256.png"
	copy_icon_with_fallback "512x512" "icon_256x256@2x.png"
	copy_icon_with_fallback "1024x1024" "icon_512x512@2x.png"
	
	iconutil --convert icns "${MOD_ID}.iconset" -o "${LAUNCHER_RESOURCES_DIR}/${MOD_ID}.icns"
	rm -rf "${MOD_ID}.iconset"

	# Set launcher metadata
	modify_plist "{MOD_ID}" "${MOD_ID}" "${LAUNCHER_CONTENTS_DIR}/Info.plist"
	modify_plist "{MOD_NAME}" "${MOD_NAME}" "${LAUNCHER_CONTENTS_DIR}/Info.plist"
	modify_plist "{JOIN_SERVER_URL_SCHEME}" "openra-${MOD_ID}-${TAG}" "${LAUNCHER_CONTENTS_DIR}/Info.plist"
	modify_plist "{DISCORD_URL_SCHEME}" "discord-${DISCORD_APPID}" "${LAUNCHER_CONTENTS_DIR}/Info.plist"

	# Sign binaries with developer certificate
	if [ -n "${MACOS_DEVELOPER_IDENTITY}" ]; then
		codesign --sign "${MACOS_DEVELOPER_IDENTITY}" --timestamp --options runtime -f --entitlements entitlements.plist --deep "${LAUNCHER_DIR}"
	fi
}

echo "Building launchers for mods: ${MODS_TO_BUILD}"

# Prepare generic template for the mods to duplicate and customize
TEMPLATE_DIR="${BUILTDIR}/template.app"
mkdir -p "${TEMPLATE_DIR}/Contents/Resources"
mkdir -p "${TEMPLATE_DIR}/Contents/MacOS/mono"
mkdir -p "${TEMPLATE_DIR}/Contents/MacOS/x86_64"
mkdir -p "${TEMPLATE_DIR}/Contents/MacOS/arm64"

echo "APPL????" > "${TEMPLATE_DIR}/Contents/PkgInfo"
cp Info.plist.in "${TEMPLATE_DIR}/Contents/Info.plist"
modify_plist "{DEV_VERSION}" "${TAG}" "${TEMPLATE_DIR}/Contents/Info.plist"
modify_plist "{FAQ_URL}" "https://wiki.openra.net/FAQ" "${TEMPLATE_DIR}/Contents/Info.plist"
modify_plist "{MINIMUM_SYSTEM_VERSION}" "10.11" "${TEMPLATE_DIR}/Contents/Info.plist"

# Compile universal (x86_64 + arm64) arch-specific apphosts
clang apphost.c -o "${TEMPLATE_DIR}/Contents/MacOS/apphost-x86_64" -framework AppKit -target x86_64-apple-macos10.15
clang apphost.c -o "${TEMPLATE_DIR}/Contents/MacOS/apphost-arm64" -framework AppKit -target arm64-apple-macos10.15
clang apphost-mono.c -o "${TEMPLATE_DIR}/Contents/MacOS/apphost-mono" -framework AppKit -target x86_64-apple-macos10.11
clang checkmono.c -o "${TEMPLATE_DIR}/Contents/MacOS/checkmono" -framework AppKit -target x86_64-apple-macos10.11

# Compile universal (x86_64 + arm64) Launcher
clang launcher.m -o "${TEMPLATE_DIR}/Contents/MacOS/Launcher-x86_64" -framework AppKit -target x86_64-apple-macos10.11
clang launcher.m -o "${TEMPLATE_DIR}/Contents/MacOS/Launcher-arm64" -framework AppKit -target arm64-apple-macos10.15
lipo -create -output "${TEMPLATE_DIR}/Contents/MacOS/Launcher" "${TEMPLATE_DIR}/Contents/MacOS/Launcher-x86_64" "${TEMPLATE_DIR}/Contents/MacOS/Launcher-arm64"
rm "${TEMPLATE_DIR}/Contents/MacOS/Launcher-x86_64" "${TEMPLATE_DIR}/Contents/MacOS/Launcher-arm64"

# Compile universal (x86_64 + arm64) Utility
clang utility.m -o "${TEMPLATE_DIR}/Contents/MacOS/Utility-x86_64" -framework AppKit -target x86_64-apple-macos10.11
clang utility.m -o "${TEMPLATE_DIR}/Contents/MacOS/Utility-arm64" -framework AppKit -target arm64-apple-macos10.15
lipo -create -output "${TEMPLATE_DIR}/Contents/MacOS/Utility" "${TEMPLATE_DIR}/Contents/MacOS/Utility-x86_64" "${TEMPLATE_DIR}/Contents/MacOS/Utility-arm64"
rm "${TEMPLATE_DIR}/Contents/MacOS/Utility-x86_64" "${TEMPLATE_DIR}/Contents/MacOS/Utility-arm64"

# Build each requested mod
for MOD_ID in "${MOD_ARRAY[@]}"; do
	if [[ -n "$(get_mod_config "${MOD_ID}")" ]]; then
		IFS='|' read -r MOD_NAME DISCORD_APPID <<< "$(get_mod_config "${MOD_ID}")"
		echo "Building ${MOD_NAME} (${MOD_ID})"
		build_app "${TEMPLATE_DIR}" "${BUILTDIR}/OpenRA - ${MOD_NAME}.app" "${MOD_ID}" "${MOD_NAME}" "${DISCORD_APPID}"
	else
		echo "Warning: Unknown mod '${MOD_ID}', skipping"
	fi
done

rm -rf "${TEMPLATE_DIR}"

# Copy built apps to output directory
echo "Copying built applications to output directory"
mkdir -p "${OUTPUTDIR}"
for MOD_ID in "${MOD_ARRAY[@]}"; do
	if [[ -n "$(get_mod_config "${MOD_ID}")" ]]; then
		IFS='|' read -r MOD_NAME DISCORD_APPID <<< "$(get_mod_config "${MOD_ID}")"
		cp -R "${BUILTDIR}/OpenRA - ${MOD_NAME}.app" "${OUTPUTDIR}/"
		echo "Copied OpenRA - ${MOD_NAME}.app to ${OUTPUTDIR}/"
	fi
done

# Create DMG files for each mod
echo "Creating DMG files for each mod"
for MOD_ID in "${MOD_ARRAY[@]}"; do
	if [[ -n "$(get_mod_config "${MOD_ID}")" ]]; then
		IFS='|' read -r MOD_NAME DISCORD_APPID <<< "$(get_mod_config "${MOD_ID}")"
		echo "Creating DMG for ${MOD_NAME} (${MOD_ID})"
		
		# Create DMG filename
		DMG_NAME="OpenRA-${MOD_NAME// /-}-${TAG}.dmg"
		DMG_PATH="${OUTPUTDIR}/${DMG_NAME}"
		
		# Create temporary directory for DMG contents
		TEMP_DMG_DIR="${BUILTDIR}/dmg-${MOD_ID}"
		mkdir -p "${TEMP_DMG_DIR}"
		
		# Copy app to temp directory
		cp -R "${BUILTDIR}/OpenRA - ${MOD_NAME}.app" "${TEMP_DMG_DIR}/"
		
		# Create symbolic link to Applications folder
		ln -sf /Applications "${TEMP_DMG_DIR}/Applications"
		
		# Create DMG using hdiutil
		hdiutil create -volname "OpenRA ${MOD_NAME}" -srcfolder "${TEMP_DMG_DIR}" -ov -format UDZO "${DMG_PATH}"
		
		# Clean up temp directory
		rm -rf "${TEMP_DMG_DIR}"
		
		echo "Created DMG: ${DMG_PATH}"
	fi
done

# Remove .app files if not keeping them
if [ "${KEEP_APPS}" != "true" ]; then
	echo "Removing .app files (DMG files created successfully)"
	for MOD_ID in "${MOD_ARRAY[@]}"; do
		if [[ -n "$(get_mod_config "${MOD_ID}")" ]]; then
			IFS='|' read -r MOD_NAME DISCORD_APPID <<< "$(get_mod_config "${MOD_ID}")"
			rm -rf "${OUTPUTDIR}/OpenRA - ${MOD_NAME}.app"
		fi
	done
else
	echo "Keeping .app files as requested"
fi

# Clean up build directory
rm -rf "${BUILTDIR}"

# Clean up keychain if we created one
if [ -n "${MACOS_DEVELOPER_CERTIFICATE_BASE64}" ] && [ -n "${MACOS_DEVELOPER_CERTIFICATE_PASSWORD}" ] && [ -n "${MACOS_DEVELOPER_IDENTITY}" ]; then
	security delete-keychain build.keychain
fi

echo "Build complete. DMG files are available in: ${OUTPUTDIR}"
