#!/bin/zsh
# Builds a Developer ID–signed, notarized and stapled DMG.
#
#   TEAM_ID=ABCDE12345 NOTARY_PROFILE=downsweep scripts/release.sh 0.1.0
#
# One-time setup on the signing Mac:
#   1. A "Developer ID Application" certificate in the login keychain (Xcode → Settings → Accounts → Manage Certificates).
#   2. Notary credentials stored in the keychain:
#        xcrun notarytool store-credentials downsweep --apple-id <you@example.com> --team-id <TEAM_ID>
#      (it prompts for an app-specific password from account.apple.com).
#
# For a local dry run without an Apple Developer account:
#   SIGNING=adhoc scripts/release.sh 0.1.0
# produces an ad-hoc signed, un-notarized DMG that Gatekeeper will warn about.
set -euo pipefail

version=${1:?usage: release.sh <version>, e.g. 0.1.0}
signing=${SIGNING:-developer-id}
root=${0:A:h:h}
out="$root/build/release"
archive="$out/Downsweep.xcarchive"
dmg="$out/Downsweep-$version.dmg"

rm -rf "$out" && mkdir -p "$out"
cd "$root"

step() { print -P "%F{blue}==>%f $1" }

if [[ $signing == developer-id ]]; then
  : ${TEAM_ID:?set TEAM_ID to your Apple Developer team ID}
  : ${NOTARY_PROFILE:?set NOTARY_PROFILE to the name used with notarytool store-credentials}
  sign_settings=(
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=Developer ID Application"
    DEVELOPMENT_TEAM="$TEAM_ID"
    OTHER_CODE_SIGN_FLAGS=--timestamp
  )
else
  sign_settings=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual)
fi

step "Archiving Downsweep $version ($signing)"
xcodebuild archive \
  -project Downsweep.xcodeproj -scheme Downsweep -configuration Release \
  -archivePath "$archive" -derivedDataPath "$root/build/DerivedData" \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
  "${sign_settings[@]}" -quiet

app="$out/Downsweep.app"
if [[ $signing == developer-id ]]; then
  step "Exporting with Developer ID"
  cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
EOF
  xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/export" \
    -exportOptionsPlist "$out/ExportOptions.plist" -quiet
  mv "$out/export/Downsweep.app" "$app"
else
  ditto "$archive/Products/Applications/Downsweep.app" "$app"
fi

step "Verifying the app signature"
codesign --verify --deep --strict --verbose=2 "$app"

step "Building the disk image"
staging="$out/dmg"
mkdir -p "$staging"
ditto "$app" "$staging/Downsweep.app"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname "Downsweep $version" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
rm -rf "$staging"

if [[ $signing == developer-id ]]; then
  step "Signing the disk image"
  codesign --sign "Developer ID Application" --timestamp "$dmg"

  step "Notarizing (this usually takes a few minutes)"
  notary_args=(--keychain-profile "$NOTARY_PROFILE")
  [[ -n ${NOTARY_KEYCHAIN:-} ]] && notary_args+=(--keychain "$NOTARY_KEYCHAIN")
  xcrun notarytool submit "$dmg" "${notary_args[@]}" --wait

  step "Stapling the notarization ticket"
  xcrun stapler staple "$dmg"

  step "Checking Gatekeeper"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
fi

shasum -a 256 "$dmg" | tee "$dmg.sha256"
step "Done: $dmg"
