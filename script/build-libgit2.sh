#!/bin/sh

# Since CMake cannot build the static and dynamic libraries in the same
# directory, this script helps build both static and dynamic versions of it and
# have the common flags in one place instead of split between two places.

set -e

usage() {
	echo "Usage: $0 <--dynamic|--static> [--system]">&2
	exit 1
}

if [ "$#" -eq "0" ]; then
	usage
fi

ROOT=${ROOT-"$(cd "$(dirname "$0")/.." && echo "${PWD}")"}
VENDORED_PATH=${VENDORED_PATH-"${ROOT}/vendor/libgit2"}
BUILD_SYSTEM=OFF

while [ $# -gt 0 ]; do
	case "$1" in
		--static)
			BUILD_PATH="${ROOT}/static-build"
			BUILD_SHARED_LIBS=OFF
			;;

		--dynamic)
			BUILD_PATH="${ROOT}/dynamic-build"
			BUILD_SHARED_LIBS=ON
			;;

		--system)
			BUILD_SYSTEM=ON
			;;

		*)
			usage
			;;
	esac
	shift
done

if [ -z "${BUILD_SHARED_LIBS}" ]; then
	usage
fi

if [ -n "${BUILD_LIBGIT_REF}" ]; then
	git -C "${VENDORED_PATH}" checkout "${BUILD_LIBGIT_REF}"
	trap "git submodule update --init" EXIT
fi

BUILD_DEPRECATED_HARD="ON"
if [ "${BUILD_SYSTEM}" = "ON" ]; then
	BUILD_INSTALL_PREFIX=${SYSTEM_INSTALL_PREFIX-"/usr"}
	# Most system-wide installations won't intentionally omit deprecated symbols.
	BUILD_DEPRECATED_HARD="OFF"
else
	BUILD_INSTALL_PREFIX="${BUILD_PATH}/install"
	mkdir -p "${BUILD_PATH}/install/lib"
fi

BUILD_TYPE="RelWithDebInfo"
USE_THREADS="ON"
USE_BUNDLED_ZLIB="ON"
if [ "${USE_CHROMIUM_ZLIB}" = "ON" ]; then
	USE_BUNDLED_ZLIB="Chromium"
	BUILD_TYPE="Release"
	CMAKE_C_FLAGS="-march=native -fomit-frame-pointer ${CMAKE_C_FLAGS}"
	if [ "${BUILD_SHARED_LIBS}" = "ON" ]; then
		CMAKE_INSTALL_DO_STRIP="/strip"
	fi

	if [ -n "${MSYSTEM}" ]; then
		CMAKE_C_FLAGS="${CMAKE_C_FLAGS} -UX86_NOT_WINDOWS -DX86_WINDOWS"

		export PATH="${PATH}:/c/Program Files/Git/cmd:/c/ProgramData/scoop/apps/git/current/cmd"
		if ! command -v git >/dev/null 2>&1; then
			echo "pacman -S git"
			exit 1
		fi
	fi
fi

if [ -n "${MSYSTEM}" ]; then
	export CMAKE_GENERATOR="MSYS Makefiles" # Ninja's broken

	if [ "${USE_THREADS}" = "OFF" ]; then
		CMAKE_C_FLAGS="${CMAKE_C_FLAGS} -DINCLUDE_win32_thread_h__"

		THREAD_C="${VENDORED_PATH}/src/util/win32/thread.c"
		if ! grep -q 'GIT_THREADS' "$THREAD_C"; then
			sed -i -b -e '1i#ifdef GIT_THREADS' -e '$a#endif /* GIT_THREADS */' "${THREAD_C}"
		fi
	fi
fi

mkdir -p "${BUILD_PATH}/build" &&
cd "${BUILD_PATH}/build" &&
cmake -DUSE_THREADS="${USE_THREADS}" \
      -DBUILD_TESTS=OFF \
      -DBUILD_SHARED_LIBS="${BUILD_SHARED_LIBS}" \
      -DREGEX_BACKEND=builtin \
      -DUSE_BUNDLED_ZLIB="${USE_BUNDLED_ZLIB}" \
      -DUSE_HTTPS=OFF \
      -DUSE_SSH=OFF \
      -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_INSTALL_PREFIX="${BUILD_INSTALL_PREFIX}" \
      -DCMAKE_INSTALL_LIBDIR="lib" \
      -DDEPRECATE_HARD="${BUILD_DEPRECATED_HARD}" \
      -DCMAKE_C_EXTENSIONS=ON \
      -DBUILD_CLI=OFF \
      -DIS_WDOCUMENTATION_SUPPORTED=0 \
      "${VENDORED_PATH}"

exec cmake --build . --parallel --target "install${CMAKE_INSTALL_DO_STRIP}"
