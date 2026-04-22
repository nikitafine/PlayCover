# Releasing

This fork should be published as:

- source code in Git
- DMG binaries as GitHub Release assets

Do not commit release binaries, IPAs, or machine-local snapshots into the repository.

## Source Build

Prepare vendored PlayTools:

```bash
./scripts/build-vendored-playtools.sh
```

Then build PlayCover from Xcode or with `xcodebuild`.

## Source-Backed Minecraft DMG

To package the fork as a public Minecraft-focused release directly from the
current source tree:

```bash
./scripts/package-source-backed-minecraft-dmg.sh
```

This script:

- builds vendored PlayTools from the tracked `Vendor/PlayTools` source
- builds `PlayCover.app` from the current fork source
- stages the tracked Minecraft helper assets from `release-assets/minecraft`
- creates a separate DMG under `../dist/`

Keep the old known-good `dist/PlayCover-Minecraft-20260420.dmg` only as a
fallback artifact. It should not be used as build input for the source-backed
release path.

## Signing And Notarization

The tracked fastlane files are templates. Set your own environment variables before using them:

- `FASTLANE_APP_IDENTIFIER`
- `FASTLANE_APPLE_ID`
- `FASTLANE_TEAM_ID`
- `MATCH_GIT_URL`

Optional:

- `FASTLANE_OUTPUT_NAME`

## GitHub Release Asset

Recommended flow:

1. Run `./scripts/package-source-backed-minecraft-dmg.sh`
2. Verify the staged app and generated `.dmg`
3. Upload the DMG to GitHub Releases
4. Keep the repository itself source-only

## Minecraft Content

- Do not redistribute the Minecraft IPA in this repository or in releases
- Do not include personal saves, account state, or machine-specific container data
