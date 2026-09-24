# Releasing Downsweep

How a release is built, signed, published, and delivered to Sparkle and Homebrew users.

- [Version and build numbers](#version-and-build-numbers)
- [Release without a Developer ID (current)](#release-without-a-developer-id-current)
- [Release with a Developer ID](#release-with-a-developer-id)
- [Automated releases from GitHub Actions](#automated-releases-from-github-actions)
- [Sparkle auto-updates](#sparkle-auto-updates)
- [Homebrew tap](#homebrew-tap)

## Version and build numbers

Pass the version to the scripts, e.g. `1.2.3`. The build number is derived from it (`1.2.3` → `10203`), so Sparkle always sees each release as newer, whether it was built locally or in CI.

## Release without a Developer ID (current)

Until the app is notarized, releases are ad-hoc signed and published from a Mac that has the Sparkle key in its login keychain and `gh` signed in.

```bash
SIGNING=adhoc scripts/release.sh 1.0.0      # build/release/Downsweep-1.0.0.dmg (+ .sha256)
scripts/appcast.sh 1.0.0                     # build/release/appcast.xml, signed with the keychain key
gh release create v1.0.0 \
  build/release/Downsweep-1.0.0.dmg \
  build/release/Downsweep-1.0.0.dmg.sha256 \
  build/release/appcast.xml \
  --title "Downsweep 1.0.0"
```

Then update the tap. `UNNOTARIZED=1` adds a caveat telling people how to open the app the first time:

```bash
UNNOTARIZED=1 scripts/cask.sh 1.0.0 build/release/Downsweep-1.0.0.dmg > ../homebrew-tap/Casks/downsweep.rb
```

Ad-hoc builds are made without the hardened runtime. With it, macOS refuses to load Sparkle.framework into an app that has no team ID, and ad-hoc builds can't be notarized anyway.

## Release with a Developer ID

Requires the paid Apple Developer Program.

1. Create a **Developer ID Application** certificate in Xcode: *Settings → Accounts → Manage Certificates*.
2. Store notarization credentials in your keychain. The command asks for an app-specific password, which you create at [account.apple.com](https://account.apple.com):

   ```bash
   xcrun notarytool store-credentials downsweep --apple-id you@example.com --team-id ABCDE12345
   ```

3. Build, sign, notarize and staple:

   ```bash
   TEAM_ID=ABCDE12345 NOTARY_PROFILE=downsweep scripts/release.sh 1.1.0
   ```

Then run `scripts/appcast.sh` and publish as above, and drop `UNNOTARIZED=1` from the cask.

## Automated releases from GitHub Actions

Pushing a tag like `v1.1.0` runs [`.github/workflows/release.yml`](../.github/workflows/release.yml). Without the Developer ID secrets it only runs the tests. With them it builds, notarizes, publishes the release, and, when their secrets exist, signs the appcast and updates the tap.

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your 10-character team ID |
| `APPLE_ID` | The Apple ID email used for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password from account.apple.com |
| `DEVELOPER_ID_CERTIFICATE_P12` | The Developer ID certificate exported as .p12, then `base64 -i cert.p12` |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | The password you set when exporting the .p12 |
| `SPARKLE_PRIVATE_KEY` | Optional. The Sparkle key, see below |
| `HOMEBREW_TAP_TOKEN` | Optional. A token that can push to the tap, see below |

## Sparkle auto-updates

Updates are signed with an EdDSA key. The app only checks for updates when `SUPublicEDKey` in [`Config/Info.plist`](../Config/Info.plist) is set, so builds without it never touch the network.

The key lives in the maintainer's login keychain. To set it up on a new machine or for CI:

```bash
# Build once so Sparkle's tools are downloaded, then:
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys      # prints the public key
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-private-key.txt
```

- The public key goes in `Config/Info.plist` (already set).
- The private key goes in the `SPARKLE_PRIVATE_KEY` secret for CI. Delete the exported file afterwards.

Each release uploads `appcast.xml` next to the DMG, and the app reads it from `releases/latest/download/appcast.xml`. `scripts/appcast.sh` starts from the published feed, so older versions stay listed.

> [!CAUTION]
> Keep the private key safe. Without it, existing installs can never be updated again.

## Homebrew tap

The cask lives in [`muhghazaliakbar/homebrew-tap`](https://github.com/muhghazaliakbar/homebrew-tap) at `Casks/downsweep.rb`. For CI to update it, create a fine-grained token with *Contents: read and write* on that repository only, and add it as `HOMEBREW_TAP_TOKEN`.

The cask sets `auto_updates true`, so Homebrew leaves updates to Sparkle.
