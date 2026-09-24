#!/bin/zsh
# Signs the release DMG and writes build/release/appcast.xml, the feed Sparkle checks for updates.
# Run after scripts/release.sh, with the EdDSA private key from Sparkle's generate_keys:
#
#   SPARKLE_PRIVATE_KEY=... scripts/appcast.sh 0.2.0
#
# The published feed is fetched first, so earlier versions stay listed.
set -euo pipefail

version=${1:?usage: appcast.sh <version>, e.g. 0.2.0}
: ${SPARKLE_PRIVATE_KEY:?set SPARKLE_PRIVATE_KEY to the key exported with generate_keys -x}
root=${0:A:h:h}
repo=https://github.com/muhghazaliakbar/downsweep
out="$root/build/release"
feed="$out/appcast"
dmg="$out/Downsweep-$version.dmg"
[[ -f $dmg ]] || { print -u2 "No $dmg; run scripts/release.sh $version first"; exit 1 }

tool=$(find "$root/build/DerivedData/SourcePackages/artifacts" -path '*Sparkle/bin/generate_appcast' -type f | head -1)
[[ -n $tool ]] || { print -u2 "generate_appcast not found; build the app once so Sparkle is resolved"; exit 1 }

rm -rf "$feed" && mkdir -p "$feed"
cp "$dmg" "$feed/"
curl -fsSL "$repo/releases/latest/download/appcast.xml" -o "$feed/appcast.xml" || rm -f "$feed/appcast.xml"

print -rn -- "$SPARKLE_PRIVATE_KEY" | "$tool" --ed-key-file - \
  --download-url-prefix "$repo/releases/download/v$version/" \
  --link "$repo" \
  "$feed"
cp "$feed/appcast.xml" "$out/appcast.xml"
print "Wrote $out/appcast.xml"
