#!/bin/zsh
# Prints the Homebrew cask for a release, e.g. for the muhghazaliakbar/homebrew-tap repository:
#
#   scripts/cask.sh 0.2.0 build/release/Downsweep-0.2.0.dmg > Casks/downsweep.rb
#
# UNNOTARIZED=1 adds a caveat explaining how to open a build that isn't notarized.
set -euo pipefail

version=${1:?usage: cask.sh <version> <dmg>}
dmg=${2:?usage: cask.sh <version> <dmg>}
sha=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
caveats=""
if [[ -n ${UNNOTARIZED:-} ]]; then
  caveats='

  caveats <<~EOS
    This build is not notarized yet. The first time you open Downsweep, macOS blocks it:
    open System Settings → Privacy & Security and click "Open Anyway".
  EOS'
fi

cat <<CASK
cask "downsweep" do
  version "$version"
  sha256 "$sha"

  url "https://github.com/muhghazaliakbar/downsweep/releases/download/v#{version}/Downsweep-#{version}.dmg"
  name "Downsweep"
  desc "Menu bar app that keeps the Downloads folder tidy"
  homepage "https://github.com/muhghazaliakbar/downsweep"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :tahoe

  app "Downsweep.app"

  zap trash: [
    "~/Library/Application Support/Downsweep",
    "~/Library/Caches/dev.downsweep.Downsweep",
    "~/Library/HTTPStorages/dev.downsweep.Downsweep",
    "~/Library/Preferences/dev.downsweep.Downsweep.plist",
  ]$caveats
end
CASK
