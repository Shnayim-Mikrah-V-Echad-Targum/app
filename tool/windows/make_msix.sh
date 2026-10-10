#!/usr/bin/env bash
# Packages the Windows release build as an MSIX installer:
# build/windows/msix/ShnayimMikra.msix. Run it from the repository root, in
# Git Bash, after `flutter build windows --release` (with the dart-defines in
# the README). The package's settings are msix_config in pubspec.yaml; extra
# arguments go to the msix tool, for example a signing certificate:
#
#   bash tool/windows/make_msix.sh --certificate-path cert.pfx \
#     --certificate-password "$PASSWORD"
#
# Without a certificate the package is signed with the msix tool's public
# test certificate, which Windows trusts only where it has been installed
# (docs/RELEASE.md).
set -euo pipefail

release=build/windows/x64/runner/Release
out=build/windows/msix

if [ ! -f "$release/shnayim_mikra.exe" ]; then
  echo "make_msix: no release build in $release; run flutter build windows --release first" >&2
  exit 1
fi
mkdir -p "$out"

# The manifest, and every icon made from windows/msix/logo.png...
dart run msix:build --output-path "$out" "$@"
# ...but at 32 px and below the app icon is the three rules alone, as in
# app_icon.ico (docs/DESIGN_SYSTEM.md §7.8; tool/branding/make_icon.py --post
# writes them under the msix tool's own file names).
cp windows/msix/Images/*.png "$release/Images/"
dart run msix:pack --output-path "$out" "$@"
