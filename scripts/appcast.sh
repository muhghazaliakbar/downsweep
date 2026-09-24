#!/bin/zsh
# Signs the release DMG and writes build/release/appcast.xml, the feed Sparkle checks for updates.
# Run after scripts/release.sh. The EdDSA private key comes from SPARKLE_PRIVATE_KEY (in CI) or,
# when that's unset, from the login keychain where Sparkle's generate_keys saved it:
#
#   scripts/appcast.sh 0.2.0
#
# The published feed is fetched first, so earlier versions stay listed.
set -euo pipefail

version=${1:?usage: appcast.sh <version>, e.g. 0.2.0}
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

args=(--download-url-prefix "$repo/releases/download/v$version/" --link "$repo" "$feed")
if [[ -n ${SPARKLE_PRIVATE_KEY:-} ]]; then
  print -rn -- "$SPARKLE_PRIVATE_KEY" | "$tool" --ed-key-file - "${args[@]}"
else
  "$tool" "${args[@]}"
fi
grep -q 'sparkle:edSignature' "$feed/appcast.xml" || { print -u2 "The appcast has no signature; check the key"; exit 1 }
cp "$feed/appcast.xml" "$out/appcast.xml"
print "Wrote $out/appcast.xml"
