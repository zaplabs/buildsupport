#!/bin/bash
#
# Build UXME for Windows and OSX
#

# error handling setup
set -o nounset -o pipefail -o errtrace

error() {
	local lc="$BASH_COMMAND" rc=$?
	echo "ERROR in $0 : line $1 exit code $2"
	echo "      [$lc]"
	exit $2
}
trap 'error ${LINENO} ${?}' ERR

# override commands
function echo() {
    command echo $(date +"[%d-%h-%Y %H:%M:%S %Z]") "$*"
}
function pushd() {
    command pushd "$@" >/dev/null
}
function popd() {
    command popd "$@" >/dev/null
}

SCRIPT_PATH="${BASH_SOURCE[0]}";
if ([ -h "${SCRIPT_PATH}" ]) then
	while([ -h "${SCRIPT_PATH}" ]) do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
fi
pushd .
cd `dirname ${SCRIPT_PATH}` > /dev/null
SCRIPT_PATH=`pwd`;
popd

# Error out if branch is dirty
if [[ ! -z $(git status --porcelain) ]]; then
    echo "Repository is not clean, aborting."
    exit 1
fi

# apply patches
echo "Applying buildbot patches"
git am --signoff "${SCRIPT_PATH}"/patches/*.patch

echo "Re/Build genie"
make genie
pushd 3rdparty/genie/src
../bin/linux/genie embed >/dev/null
popd
make genieclean >/dev/null
make genie >/dev/null

NPROC=$(getconf _NPROCESSORS_ONLN)
LLIMIT=$((${NPROC} * 2)) # $(awk 'BEGIN{printf"%.1f",'${NPROC}'/2}')

echo "Build: ${NPROC} jobs, ${LLIMIT} load limit"

echo Windows 64-bit release version:

make TARGETOS=windows TOOLCHAIN=x86_64-w64-mingw32.static- TARGET=mame TOOLS=1 SEPARATE_BIN=1 PTR64=1 STRIP_SYMBOLS=1 OPTIMIZE=3 SYMBOLS=1 SYMLEVEL=1 REGENIE=1 SHELLTYPE=posix PRECOMPILE=0 -j${NPROC} -l${LLIMIT} | awk 'BEGIN { x = ""; } { if ($1 != x) { print("\n" $0); } else { print("") } x = $1; }' ORS='.'

export MACOSX_DEPLOYMENT_TARGET=10.7
`osxcross-conf`

echo MACOSX 64-bit release version:

make TARGETOS=macosx TOOLCHAIN=x86_64-apple-darwin11- TARGET=mame TOOLS=1 SEPARATE_BIN=1 PTR64=1 STRIP_SYMBOLS=1 OPTIMIZE=2 REGENIE=1 USE_SYSTEM_LIB_EXPAT=1 USE_SYSTEM_LIB_ZLIB=1 USE_LIBSDL=1 USE_QTDEBUG=0 CLANG_VERSION=3.5.0 ARCHOPTS="-stdlib=libc++ -std=c++1y" SHELLTYPE=posix -j${NPROC} -l${LLIMIT} | awk 'BEGIN { x = ""; } { if ($1 != x) { print("\n" $0); } else { print("") } x = $1; }' ORS='.'

