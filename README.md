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

  <h3 align="center">PlayCover</h3>

  <p align="center">
    Minecraft Bedrock-focused PlayCover fork for running the iOS version on Apple Silicon Macs.
    <br />
    <br />
    <a href="https://playcover.github.io/PlayBook">Documentation</a>
    ·
    <a href="https://discord.gg/RNCHsQHr3S">Discord</a>
    ·
    <a href="https://playcover.io/">Website</a>
  </p>
</div>

## Fork Notice

This repository is a Minecraft Bedrock-focused fork of PlayCover. The goal is to keep the upstream PlayCover project recognizable while documenting the extra launcher/runtime work needed to run the iOS version of Minecraft on Apple Silicon Macs.

- upstream PlayCover remains the main project and primary upstream for the app itself
- this fork vendors the matching `PlayTools` source tree in-repo so Minecraft-specific runtime fixes can ship from one repository
- the sections below still largely follow the upstream README so upstream authorship and project context stay visible

Maintainer notes for the one-repo layout are in [MINECRAFT_FORK.md](./MINECRAFT_FORK.md).

## Current Limitations

This fork is usable for Minecraft Bedrock, but it still has known shortcomings:

- in-game scrolling is not fully correct yet
  - menu scrolling is mostly fine
  - world/in-game scrolling can still be interpreted as touch-style camera or hotbar gestures
- controller support is not solved
  - PlayCover/PlayTools currently rely on Apple's `GameController` stack rather than shipping a generic HID-to-iOS gamepad bridge
  - some controllers work in some games, but Minecraft controller support is not reliably fixed in this fork
- hanging process on quit is not fully fixed at the runtime level
  - the launcher now includes stale-process relaunch cleanup
  - Minecraft itself may still leave behind a stuck `minecraftpe` process after quitting
- high-refresh / 120 Hz support is intentionally not part of the published Minecraft fix set
  - experimental FPS unlocking work existed locally during development
  - it was not stable enough to ship in this fork

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

Lucas Lee - playcover@lucas.icu

Depal - depal@playcover.io




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
