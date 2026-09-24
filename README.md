<img src="docs/icon.png" width="128" alt="Downsweep icon">

# Downsweep

A menu bar app that keeps your Mac's Downloads folder tidy without you writing a single rule.

![Review window](docs/review.png)

- **Installers you've already used.** Downsweep looks inside DMG, ZIP and PKG files. If the app they contain is already installed (same version or newer), it suggests moving the installer to the Trash.
- **Duplicate downloads.** It finds `report (1).pdf` when the file is byte-for-byte identical to `report.pdf`.
- **Sort by source.** Browsers record where every download came from. Downsweep can move files from `mail.google.com` to Attachments, or files from `github.com` to your code folder.
- **Stale files.** Files you haven't opened in 30 days get a Finder "Stale" tag. If you still don't open them after another 14 days, Downsweep suggests the Trash.

**Nothing is ever deleted.** Everything goes to the Trash, and every action can be undone from History.

## Requirements

- macOS 26 or later (the UI uses Liquid Glass)
- Xcode 26 or later to build

## Build

```bash
open Downsweep.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project Downsweep.xcodeproj -scheme Downsweep build
```

## Project layout

```
Downsweep/                 SwiftUI app: menu bar, Review window, onboarding, Settings
Packages/SweepCore/        All decision logic, UI-free and unit-tested
  Scanner/                 Folder listing + Spotlight metadata (date added, last opened, source URL)
  Inspectors/              DMG / ZIP / PKG inspection, installed-app index, duplicate finder
  Policy/                  PolicyEngine (pure: items → proposals) and SweepPipeline
  Executor/                The only code that touches files: Trash, move, tag, undo
  Watcher/                 FSEvents folder watcher
  Store/                   Action history
scripts/make-fixtures.sh   Builds a fake Downloads folder for development
scripts/release.sh         Signed + notarized DMG
scripts/render-icon-layers.swift  Redraws the app icon's layers
```

`PolicyEngine` is a pure function. If you want to change what Downsweep suggests, start there and in its tests.

## Development

Run the core tests:

```bash
swift test --package-path Packages/SweepCore
```

To try the app without touching your real Downloads folder, build a fixture folder and point Downsweep at it (Settings → General → Folder):

```bash
scripts/make-fixtures.sh /tmp/DownsweepFixtures
```

Fixtures are brand new, so nothing looks stale. Debug builds accept launch arguments that pretend time has passed. You can add them in Xcode under *Edit Scheme → Run → Arguments*:

| Argument | Effect |
| --- | --- |
| `-DebugClockOffsetDays 40` | Treat "now" as 40 days ahead |
| `-DebugOpenReview YES` | Open the Review window at launch |

End-to-end test over the fixtures (mounts the DMGs for real):

```bash
DOWNSWEEP_FIXTURES=/tmp/DownsweepFixtures swift test --package-path Packages/SweepCore --filter FixturePipeline
```

## Releasing

`scripts/release.sh` archives the app, signs it with Developer ID, builds a DMG, then notarizes and staples it.

One-time setup (requires the paid Apple Developer Program):

1. Create a **Developer ID Application** certificate in Xcode: *Settings → Accounts → Manage Certificates*.
2. Store notarization credentials in your keychain. The command prompts for an app-specific password, which you create at account.apple.com:

   ```bash
   xcrun notarytool store-credentials downsweep --apple-id you@example.com --team-id ABCDE12345
   ```

Then build a release locally:

```bash
TEAM_ID=ABCDE12345 NOTARY_PROFILE=downsweep scripts/release.sh 0.1.0
```

`SIGNING=adhoc scripts/release.sh 0.1.0` makes an unsigned test DMG without an Apple account.

### From GitHub Actions

Pushing a tag like `v0.1.0` runs `.github/workflows/release.yml`, which publishes the DMG as a GitHub Release. Before that, add these repository secrets:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your 10-character team ID |
| `APPLE_ID` | The Apple ID email used for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password from account.apple.com |
| `DEVELOPER_ID_CERTIFICATE_P12` | The Developer ID certificate exported as .p12, then `base64 -i cert.p12` |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | The password you set when exporting the .p12 |

## Design notes

- The UI follows Apple's Human Interface Guidelines for macOS 26. It uses system fonts, SF Symbols, semantic colours and standard controls.
- Liquid Glass is used only for the navigation and controls layer. That means menu bar tiles, the floating selection bar, toolbar buttons, and the onboarding pager. Content rows stay plain, as the HIG recommends.
- Glass elements that sit next to each other share a `GlassEffectContainer` so they blend and morph together.

## Roadmap

### v0.1 — first public release

- [x] Lifecycle: new → active → idle → stale (Finder tag) → Trash, with adjustable thresholds
- [x] Installer detection for DMG, ZIP and PKG, compared against installed app versions
- [x] Duplicate detection: `name (1).ext` / `name-1.ext`, confirmed by SHA-256
- [x] Source rules from `kMDItemWhereFroms` (e.g. `mail.google.com` → Attachments)
- [x] Review window, History with undo, onboarding, Settings
- [x] Review and Automatic modes, with a safety limit of 50 items or 10 GB per sweep
- [x] App icon (Icon Composer, Liquid Glass)
- [x] Release pipeline: signed, notarized DMG published to GitHub Releases on each `v*` tag
- [ ] First notarized release (needs a Developer ID certificate, see [Releasing](#releasing))

### v1.0

- [ ] Weekly summary notification, with a shareable "cleaned this week" card
- [ ] Sparkle auto-updates
- [ ] Homebrew Cask
- [ ] Indonesian localization, alongside English
- [ ] SQLite (GRDB) history store in place of JSON
- [x] Wait for files to settle before acting: nothing changed in the last 2 minutes, re-checked (folders included) right before acting

### Later

- [ ] Watch additional folders, starting with Desktop
- [ ] Shortcuts actions (App Intents), e.g. "Sweep Downloads now"
- [ ] Companion CLI: `downsweep scan --dry-run`
- [ ] On-device grouping with Apple Foundation Models, staying 100% local

Have an idea? [Open an issue](https://github.com/muhghazaliakbar/downsweep/issues).

## Privacy & safety

- Local only. There is no analytics and no network access.
- Downsweep only acts on items at the top level of the watched folder. It leaves alone anything that changed in the last 2 minutes (still downloading, copying or unpacking). Right before acting, it re-checks that each file still exists and hasn't changed size, and that nothing inside a folder has changed, since the scan.
- Automatic mode stops and asks before moving more than 50 items or 10 GB at once.
- Downsweep ships without the App Sandbox. It has to run `hdiutil` and `pkgutil` to look inside installers, and those tools don't work reliably from a sandboxed process. It uses the Hardened Runtime.

## License

MIT
