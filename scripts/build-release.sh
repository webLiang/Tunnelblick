#!/bin/bash
# Build and package a locally signed Universal Tunnelblick release.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
export MAKEFLAGS="${MAKEFLAGS:--j8}"
# Host Homebrew flags can mix OpenSSL 3 headers into bundled OpenSSL 1.1.
unset CPPFLAGS CFLAGS CXXFLAGS LDFLAGS CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR OPENSSL_PREFIX PYTHON_CONFIGURE_OPTS
python3 tests/run-tests.py
mkdir -p dist
# The legacy preparation target removes this bundle during the build. Remove it
# before Xcode plans incremental work so it also recreates the linked executable.
rm -rf "$TASK_ROOT/tunnelblick/build/Release/Tunnelblick.app"
xcodebuild -project tunnelblick/Tunnelblick.xcodeproj -scheme Tunnelblick \
    -configuration Release -derivedDataPath "$TASK_ROOT/tunnelblick/build/DerivedData" \
    SYMROOT="$TASK_ROOT/tunnelblick/build" OBJROOT="$TASK_ROOT/tunnelblick/build/Intermediates" \
    CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO ARCHS="arm64 x86_64" build > build-log.txt 2>&1 || {
    tail -80 build-log.txt
    exit 1
}
python3 scripts/package-release.py
