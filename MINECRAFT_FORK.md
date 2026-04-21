## Minecraft Fork Notes

This fork keeps the normal GitHub fork relationship with `PlayCover/PlayCover` and vendors the `PlayTools` source tree inside this repository at `Vendor/PlayTools`.

That gives us:

- one GitHub repo to clone, file issues against, and release from
- normal upstream sync for `PlayCover`
- preserved upstream history and authorship for `PlayTools`

### Included Minecraft fixes

PlayCover-side commit carried into this fork:

- `09864fed2d01d091c51cf5e245af702dfece06d1`
  - direct executable launch for Minecraft
  - cleaner launch environment
  - launcher alias handling
  - `playcoverapp://` URL open flow

PlayTools-side vendored state imported into `Vendor/PlayTools`:

- `ffce9b2767e6c70ef233bdb01b62842c75296122`
  - Minecraft Bedrock runtime fixes
  - keychain safety fixes
  - UDP nonblocking socket hook
  - Discord/SwordRPC removal
- `ce161e3b7752631faa5a8ae8260ae374519bb8ca`
  - follow-up keychain crash fix
  - SQLite busy timeout

Later local experiments around FPS tuning, scroll behavior, and controller investigation were intentionally not included in this branch.

### Repo layout

- repo root: fork of `PlayCover/PlayCover`
- `Vendor/PlayTools`: vendored `PlayCover/PlayTools` subtree

### Building

`PlayCover` still expects a built `PlayTools.framework` under:

`Carthage/Build/PlayTools.xcframework/ios-arm64/PlayTools.framework`

Use:

```bash
./scripts/build-vendored-playtools.sh
```

before building PlayCover in Xcode or via `xcodebuild`.

### Upstream sync

Sync PlayCover upstream as a normal fork:

```bash
git fetch upstream
git merge upstream/develop
```

Sync the vendored PlayTools subtree:

```bash
./scripts/sync-playtools-subtree.sh
```

If you have not configured the PlayTools upstream remote yet:

```bash
git remote add playtools-upstream https://github.com/PlayCover/PlayTools.git
```

### Attribution

`Vendor/PlayTools` was imported with `git subtree`, not copied as anonymous files. Upstream PlayTools history and authorship are preserved in this repository history even though GitHub only displays this repo as a fork of `PlayCover`.
