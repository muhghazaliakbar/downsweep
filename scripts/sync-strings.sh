#!/bin/zsh
# Pulls new user-facing strings from the source into the String Catalogs.
# xcodebuild doesn't do this on its own (Xcode's IDE does), so run it after adding strings:
#
#   scripts/sync-strings.sh
#
# New strings then show up untranslated in the catalogs, ready for Indonesian.
set -euo pipefail
cd "${0:A:h}/.."

derived=build/StringsData
rm -rf $derived
xcodebuild -project Downsweep.xcodeproj -scheme Downsweep -configuration Debug \
  -derivedDataPath $derived CODE_SIGNING_ALLOWED=NO SWIFT_EMIT_LOC_STRINGS=YES build -quiet

sync() {
  local catalog=$1 target=$2
  local files=(${(f)"$(find $derived/Build/Intermediates.noindex/$target.build -name '*.stringsdata')"})
  local args=()
  for f in $files; do args+=(--stringsdata $f); done
  xcrun xcstringstool sync $catalog $args
  echo "Synced $catalog"
}
sync Downsweep/Localizable.xcstrings Downsweep
sync Packages/SweepCore/Sources/SweepCore/Resources/Localizable.xcstrings SweepCore
