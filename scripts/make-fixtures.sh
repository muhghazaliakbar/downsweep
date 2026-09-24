#!/bin/zsh
# Builds a fake Downloads folder for trying Downsweep without touching your real one.
#
#   scripts/make-fixtures.sh /tmp/DownsweepFixtures
#
# Then run the Debug build with:
#   -DebugClockOffsetDays 60   (makes the fresh files look two months old)
set -euo pipefail

target=${1:?usage: make-fixtures.sh <folder>}
rm -rf "$target" && mkdir -p "$target"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# An installer for an app that IS installed: copy a real app's Info.plist into a stub bundle.
installed=$(find /Applications -maxdepth 1 -name "*.app" -print -quit)
name=$(basename "$installed" .app)
mkdir -p "$work/dmg/$name.app/Contents"
cp "$installed/Contents/Info.plist" "$work/dmg/$name.app/Contents/Info.plist"
hdiutil create -quiet -srcfolder "$work/dmg" -volname "$name" -format UDZO "$target/$name-Installer.dmg"
(cd "$work/dmg" && ditto -c -k --keepParent "$name.app" "$target/$name.zip")

# An installer for an app that is NOT installed.
mkdir -p "$work/new/Nimbus.app/Contents"
plutil -create xml1 "$work/new/Nimbus.app/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string dev.downsweep.fixture.nimbus "$work/new/Nimbus.app/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string 1.0 "$work/new/Nimbus.app/Contents/Info.plist"
hdiutil create -quiet -srcfolder "$work/new" -volname Nimbus -format UDZO "$target/Nimbus-1.0.dmg"

# Duplicates: one identical pair, one look-alike with different bytes.
head -c 200000 /dev/urandom > "$target/Quarterly Report.pdf"
cp "$target/Quarterly Report.pdf" "$target/Quarterly Report (1).pdf"
head -c 50000 /dev/urandom > "$target/photo.png"
head -c 50000 /dev/urandom > "$target/photo (1).png"

# Files with a browser-recorded source, for source rules.
where_froms() {
  python3 -c 'import plistlib,sys; print(plistlib.dumps(sys.argv[1:], fmt=plistlib.FMT_BINARY).hex())' "$@"
}
head -c 80000 /dev/urandom > "$target/release-notes.zip"
xattr -wx com.apple.metadata:kMDItemWhereFroms "$(where_froms https://codeload.github.com/x/y https://github.com/x/y)" "$target/release-notes.zip"
head -c 120000 /dev/urandom > "$target/Invoice-0925.pdf"
xattr -wx com.apple.metadata:kMDItemWhereFroms "$(where_froms https://mail-attachment.googleusercontent.com/a https://mail.google.com/mail/u/0/)" "$target/Invoice-0925.pdf"

# Plain old files and a folder.
head -c 30000 /dev/urandom > "$target/meeting-notes.txt"
mkdir -p "$target/Project Assets" && head -c 400000 /dev/urandom > "$target/Project Assets/hero.psd"

echo "Fixtures in $target (installed app used: $name)"
