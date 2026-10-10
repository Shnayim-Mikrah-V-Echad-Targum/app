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

# The app's name in each of the package's languages: msix_config's
# display_name is ms-resource:AppName, from Strings/<language>/Resources.resw.
rm -rf "$release/Strings"
cp -R windows/msix/Strings "$release/Strings"

# The manifest, and every icon made from windows/msix/logo.png...
dart run msix:build --output-path "$out" "$@"
# ...but at 32 px and below the app icon is the three rules alone, as in
# app_icon.ico (docs/DESIGN_SYSTEM.md §7.8; tool/branding/make_icon.py --post
# writes them under the msix tool's own file names).
cp windows/msix/Images/*.png "$release/Images/"

# Index the resources again, into one resources.pri (windows/msix/priconfig.xml
# says why), with the msix tool's own MakePri.
root=$(sed -n 's|.*"rootUri": *"file://\([^"]*/msix-[0-9][^"]*\)".*|\1|p' .dart_tool/package_config.json | head -n 1)
root=${root//%20/ }
case "$root" in /[A-Za-z]:/*) root=${root#/} ;; esac
makepri="$root/lib/assets/MSIX-Toolkit/Redist.x64/MakePri.exe"
if [ ! -f "$makepri" ]; then
  echo "make_msix: no MakePri.exe in the msix package ($root)" >&2
  exit 1
fi
win() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
rm -f "$release"/resources*.pri
# MSYS_NO_PATHCONV keeps Git Bash from taking MakePri's /options for paths.
MSYS_NO_PATHCONV=1 "$makepri" new /cf "$(win windows/msix/priconfig.xml)" /pr "$(win "$release")" \
  /mn "$(win "$release/AppxManifest.xml")" /of "$(win "$release/resources.pri")" /o
MSYS_NO_PATHCONV=1 "$makepri" dump /if "$(win "$release/resources.pri")" /of "$(win "$out/resources.xml")" \
  /dt detailed /o
# The dump may be UTF-16.
if ! tr -d '\000' < "$out/resources.xml" | grep -qi 'language-he'; then
  echo "make_msix: resources.pri has no Hebrew name for the app (see $out/resources.xml)" >&2
  exit 1
fi

dart run msix:pack --output-path "$out" "$@"
