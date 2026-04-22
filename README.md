<div id="top"></div>

‎<h1 align="center">[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![GPLv3 License][license-shield]][license-url]
[![Weblate](https://img.shields.io/weblate/progress/playcover?style=for-the-badge)](https://hosted.weblate.org/projects/playcover/playcover/)
</h1>



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/PlayCover/PlayCover">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">PlayCover Minecraft</h3>

  <p align="center">
    A PlayCover fork focused on running Minecraft Bedrock for iOS/iPadOS on Apple Silicon Macs.
    <br />
    <br />
    <a href="https://playcover.github.io/PlayBook">Documentation</a>
    ·
    <a href="https://discord.gg/RNCHsQHr3S">Discord</a>
    ·
    <a href="https://playcover.io/">Website</a>
  </p>
</div>

## Minecraft Bedrock Fork

This repository exists specifically to run the iOS/iPadOS version of Minecraft Bedrock on Apple Silicon Macs.

- this is a PlayCover fork, not the upstream PlayCover release channel
- you need your own decrypted Minecraft Bedrock IPA file
- this repository and its releases do not include Minecraft itself
- prebuilt DMGs for this fork belong in GitHub Releases

## Quick Start

1. Download the latest DMG release from this fork.
2. Drag `PlayCover.app` into `/Applications`.
3. If macOS blocks it, right-click `PlayCover.app` and choose `Open` once.
4. Run `Install Minecraft IPA.sh` from the DMG.
5. Select a decrypted Minecraft Bedrock IPA.
6. Launch Minecraft from PlayCover or from the generated launcher app in `~/Applications/PlayCover`.

## What You Need

- an Apple Silicon Mac
- macOS 12 or newer
- a decrypted Minecraft Bedrock IPA for iOS/iPadOS
- Xcode Command Line Tools if you want to build from source

## Current Minecraft Limitations

- scrolling is still imperfect
- mouse wheel support is not fully correct in-game
- the shipped public build is capped at 60 FPS
- controller support is not implemented yet
- with Vibrant Visuals enabled, the practical render-distance ceiling is about 12 chunks

## Fork Notice

This repository is a Minecraft Bedrock-focused fork of PlayCover. The goal is to keep the upstream PlayCover project recognizable while documenting the extra launcher/runtime work needed to run the iOS version of Minecraft on Apple Silicon Macs.

- upstream PlayCover remains the main project and primary upstream for the app itself
- this fork vendors the matching `PlayTools` source tree in-repo so Minecraft-specific runtime fixes can ship from one repository
- source builds use the vendored `PlayTools` tree in `Vendor/PlayTools`
- release binaries belong in GitHub Releases as DMG assets, not committed to git
- the sections below still largely follow the upstream README so upstream authorship and project context stay visible

Maintainer notes for the one-repo layout are in [MINECRAFT_FORK.md](./MINECRAFT_FORK.md).

## Releases

Use GitHub Releases from this fork for prebuilt DMGs. The repository should stay source-first:

- do not commit DMGs, IPAs, or user-specific snapshots to git
- upload the finished DMG as a release asset
- keep Minecraft itself out of the repository and out of releases

<!-- ABOUT THE PROJECT -->
## About The Project

Welcome to PlayCover! This software is all about allowing you to run iOS apps and games on Apple Silicon devices running macOS 12.0 or newer.

PlayCover works by putting applications through a wrapper which imitates an iPad. This allows the apps to run natively and perform very well.

This fork is focused on Minecraft Bedrock support. In addition to the upstream PlayCover app changes, it vendors the matching `PlayTools` source tree in-repo so the launcher/runtime fixes needed for Minecraft can be maintained and released from a single repository.

PlayCover also allows you to map custom touch controls to keyboard, which is not possible in alternative sideloading methods such as Sideloadly. 

These controls include all the essentials, from WASD, camera movement, left and right clicks, and individual keymapping, similar to a popular Android emulator’s keymapping system called Bluestacks.

This software was originally designed to run Genshin Impact on your Apple Silicon device, but it can now run a wide range of applications. Unfortunately, not all games are supported, and some may have bugs.

Localisations handled in [Weblate](https://hosted.weblate.org/projects/playcover/).

![Fancy logo](./images/dark.png#gh-dark-mode-only)
![Fancy logo](./images/light.png#gh-light-mode-only)

<p align="right"><a href="#top">⬆️ Back to top️</a></p>

<!-- GETTING STARTED -->
## Getting Started

Follow the instructions below to get Genshin Impact, and many other games, up and running in no time.

### Prerequisites

At the moment, PlayCover can only run on Apple Silicon Macs. This means that only devices with M-series SoCs (eg. M1) are supported.

If you have an Intel Mac, you can explore alternatives like Bootcamp or emulators.

### Download

Upstream PlayCover stable releases are [here](https://github.com/PlayCover/PlayCover/releases). For this fork, prefer GitHub Releases from this repository or build from source.

### Minecraft Install

This fork expects a decrypted Minecraft Bedrock IPA. It does not include one.

Recommended install flow:

1. Install `PlayCover.app` from this fork's DMG.
2. Open `Install Minecraft IPA.sh`.
3. Select your decrypted IPA.
4. Let the helper import the app and apply the Minecraft-specific working state.
5. Launch Minecraft from PlayCover or the generated launcher.

### Build From Source

If you want to build the app and package the Minecraft DMG yourself:

```sh
git clone https://github.com/nikitafine/PlayCover.git
cd PlayCover
./scripts/package-source-backed-minecraft-dmg.sh
```

That script:

- builds the vendored `PlayTools` tree from `Vendor/PlayTools`
- builds `PlayCover.app` from the current source tree
- stages the Minecraft helper assets from `release-assets/minecraft`
- creates a source-backed DMG under `../dist/`

If you only want the app build without packaging a DMG:

```sh
./scripts/build-vendored-playtools.sh
xcodebuild build \
  -project PlayCover.xcodeproj \
  -scheme PlayCover \
  -configuration Release \
  -derivedDataPath .source-backed-release-build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="-" \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  CLANG_ENABLE_EXPLICIT_MODULES=NO
```

### Documentation

To learn how to setup and use PlayCover, visit the documentation [here](https://playcover.github.io/PlayBook).

### Homebrew Cask
This section refers to the upstream PlayCover cask. It should not be treated as an installation path for this Minecraft-focused fork unless a separate fork-specific cask is published.

We host a [Homebrew](https://brew.sh) tap with the [PlayCover cask](https://github.com/PlayCover/homebrew-playcover/blob/master/Casks/playcover-community.rb). To install from it run:

```sh
brew install --cask PlayCover/playcover/playcover-community
```

To uninstall:
1. Remove PlayCover using `brew uninstall --cask playcover-community`;
2. Untap `PlayCover/playcover` with `brew untap PlayCover/playcover`.

<p align="right"><a href="#top">⬆️ Back to top️</a></p>



<!-- LICENSE -->
## License

Distributed under the GPLv3 License. See `LICENSE` for more information.



<!-- CONTACT -->
## Contact

For Minecraft-specific issues in this fork, use this repository's GitHub Issues.
For general upstream PlayCover discussion, use the upstream PlayCover repository and community channels.




<!-- ACKNOWLEDGMENTS -->
## Libraries Used

These open source libraries were used to create this project.

* [inject](https://github.com/paradiseduo/inject)
* [PTFakeTouch](https://github.com/Ret70/PTFakeTouch)
* [DownloadManager](https://github.com/shapedbyiris/download-manager)
* [DataCache](https://github.com/huynguyencong/DataCache)
* [SwiftUI CachedAsyncImage](https://github.com/bullinnyc/CachedAsyncImage)

* Thanks to @iVoider for creating such a great project!

<p align="right"><a href="#top">⬆️ Back to top️</a></p>



<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/PlayCover/PlayCover.svg?style=for-the-badge
[contributors-url]: https://github.com/PlayCover/PlayCover/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/PlayCover/PlayCover.svg?style=for-the-badge
[forks-url]: https://github.com/PlayCover/PlayCover/network/members
[stars-shield]: https://img.shields.io/github/stars/PlayCover/PlayCover.svg?style=for-the-badge
[stars-url]: https://github.com/PlayCover/PlayCover/stargazers
[issues-shield]: https://img.shields.io/github/issues/PlayCover/PlayCover.svg?style=for-the-badge
[issues-url]: https://github.com/PlayCover/PlayCover/issues
[license-shield]: https://img.shields.io/github/license/PlayCover/PlayCover.svg?style=for-the-badge
[license-url]: https://github.com/PlayCover/PlayCover/blob/master/LICENSE
