#!/bin/zsh
# Commits the cask for a release to the Homebrew tap. Needs GH_TOKEN with push access to the tap.
#
#   GH_TOKEN=... scripts/update-tap.sh 0.2.0
set -euo pipefail

version=${1:?usage: update-tap.sh <version>}
: ${GH_TOKEN:?set GH_TOKEN to a token that can push to the tap}
root=${0:A:h:h}
tap=${HOMEBREW_TAP:-muhghazaliakbar/homebrew-tap}
work=$(mktemp -d)

git clone --depth 1 "https://x-access-token:$GH_TOKEN@github.com/$tap.git" "$work"
mkdir -p "$work/Casks"
"$root/scripts/cask.sh" "$version" "$root/build/release/Downsweep-$version.dmg" > "$work/Casks/downsweep.rb"

cd "$work"
git add Casks/downsweep.rb
if git diff --cached --quiet; then
  print "Cask already up to date"
  exit 0
fi
git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "downsweep $version"
git push
