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

### 2026-07 sync and findings

Synced in July 2026 (verified working with Minecraft Bedrock 1.26.32 on macOS 27.0 beta):

- merged upstream `PlayCover/develop` (custom user directory crash fix, Unity keyboard toggle)
- cherry-picked from upstream PlayTools: macOS Tahoe MenuController fix (#188/#197),
  motion update throttle (#195), window-close crash fix (#199), `sysctlbyname`
  string termination (#212), disable-builtin-mouse toggle (#201)
- ported scroll-to-key mapping (open PRs PlayTools #218 + PlayCover #2112):
  ScrU/ScrD virtual keys, `enableScrollWheel` split into
  `enableScrollWheelZoom`/`enableScrollWheelMapping`
- keychain: generated SecKeys are now persisted to the PlayChain DB
  (upstream #215), `copyMatching` reads the `type`/`kcls` columns and falls
  back to raw key data instead of `errSecItemNotFound`, `add()` always
  populates the caller's result pointer
- UDP `O_NONBLOCK` hook and launcher `pkill` cleanup are scoped/anchored
- CI: `.github/workflows/3.minecraft_dmg.yml` builds the DMG on a macOS
  runner (`workflow_dispatch`, no signing secrets needed) — no local Xcode
  required

Known incompatibilities and dead ends (do not re-apply blindly):

- upstream PlayTools controller fixes #206 (`dcc6b10`) and #213 (`3838cd6`,
  `ControllerFocus.m`) set `GCController.shouldMonitorBackgroundEvents = true`;
  on macOS 27.0 beta this kills ALL input (mouse clicks and keyboard) in the
  game — and controller input did NOT work either while they were applied,
  so the patch buys nothing here. Both were cherry-picked and then reverted.
  Retest on future macOS releases before re-applying.
- working input (clicks, mouse look, keyboard) flows through the Catalyst
  touch/pointer translation; everything that depends on the GameController
  framework is broken under PlayCover on macOS 27 (GCMouse scroll arrives
  axis-mangled, GCController events never arrive). A future investigation
  should start with a diagnostic PlayTools build that logs GCMouse.current,
  GCController.controllers(), and scroll handler activity in-process to map
  what the framework actually delivers before attempting fixes.
- the scroll axis bug (vertical wheel input does nothing; horizontal input
  scrolls vertically) lives BELOW the NSEvent layer: Minecraft reads scroll
  via GameController/HID (`GCMouse`), so neither PlayTools' scroll
  interceptor (`enableScrollWheelZoom` on or off — no difference) nor an
  NSEvent-level axis-swap monitor (tried, reverted) has any effect. A future
  fix needs to hook the GameController layer inside the game process, e.g.
  swizzle `GCControllerDirectionPad.setValueChangedHandler` (or the polled
  axis values) for the `GCMouseInput.scroll` cursor and swap x/y there.
- `disableBuiltinMouse = true` makes things worse for Minecraft with
  keymapping off (the game loses `GCMouse` without gaining a touch
  fallback); keep it `false`.

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

By default this script builds `PlayTools` from the vendored source tree.
If you deliberately want to stage a prebuilt framework instead, set:

```bash
PLAYCOVER_PREBUILT_PLAYTOOLS_FRAMEWORK=/path/to/PlayTools.framework ./scripts/build-vendored-playtools.sh
```

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
