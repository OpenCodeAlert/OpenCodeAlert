#!/bin/bash
# OpenRA master packaging script

set -o errexit -o pipefail || exit $?

if [ $# -lt "2" ] || [ $# -gt "3" ]; then
	echo "Usage: $(basename "$0") version outputdir [mods]"
	echo "  mods: comma-separated list of mods to build (default: copilot for macOS, all for others)"
	echo "        available mods: copilot, ra, cnc, d2k, ts"
	echo "        examples: 'copilot' or 'ra,cnc,d2k' or 'all' for all mods"
	exit 1
fi

export GIT_TAG="$1"
export BUILD_OUTPUT_DIR="$2"
export MODS_TO_BUILD="${3:-}"

# Set the working dir to the location of this script
HERE=$(dirname "$0")
cd "${HERE}"

#build packages using a subshell so directory changes do not persist beyond the function
function build_package() (
	function on_build() {
		echo "$1 package build failed." 1>&2
	}
	#trap function executes on any error in the following commands
	trap "on_build $1" ERR
	echo "Building $1 package(s)."
	cd "$1"
	if [ "$1" = "macos" ] && [ -n "${MODS_TO_BUILD}" ]; then
		./buildpackage.sh "${GIT_TAG}" "${BUILD_OUTPUT_DIR}" "${MODS_TO_BUILD}"
	elif [ "$1" = "linux" ] && [ -n "${MODS_TO_BUILD}" ]; then
		./buildpackage.sh "${GIT_TAG}" "${BUILD_OUTPUT_DIR}" "${MODS_TO_BUILD}"
	else
		./buildpackage.sh "${GIT_TAG}" "${BUILD_OUTPUT_DIR}"
	fi
)

if [[ "$OSTYPE" == "darwin"* ]]; then
  build_package macos
else
  build_package windows
  build_package linux
  build_package source
fi

echo "Package build done."
