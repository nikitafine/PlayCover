//
//  PlayAppExtensions.swift
//  PlayCover
//
//  Created by TheMoonThatRises on 10/2/23.
//

import Foundation

extension PlayApp {
    private var launcherContentsURL: URL {
        aliasURL.appendingPathComponent("Contents")
    }

    private var launcherMacOSURL: URL {
        launcherContentsURL.appendingPathComponent("MacOS")
    }

    private var launcherResourcesURL: URL {
        launcherContentsURL.appendingPathComponent("Resources")
    }

    private var launcherInfoPlistURL: URL {
        launcherContentsURL.appendingPathComponent("Info.plist")
    }

    private var launcherExecutableURL: URL {
        launcherMacOSURL.appendingPathComponent("launcher")
    }

    private var launcherBundleIdentifier: String {
        "io.playcover.launcher.\(info.bundleIdentifier)"
    }

    private var launcherOpenURL: String {
        "playcoverapp://app?action=open&bundleId=\(info.bundleIdentifier)"
    }

    private func writeLauncherInfoPlist() throws {
        var launcherInfo: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleExecutable": launcherExecutableURL.lastPathComponent,
            "CFBundleIdentifier": launcherBundleIdentifier,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": info.bundleVersion.isEmpty ? "1.0" : info.bundleVersion,
            "CFBundleVersion": info[string: "CFBundleVersion"] ?? "1",
            "LSApplicationCategoryType": info.applicationCategoryType.rawValue,
            "NSPrincipalClass": "NSApplication"
        ]

        if let iconName = linkLauncherIcon() {
            launcherInfo["CFBundleIconFile"] = iconName
        }

        let data = try PropertyListSerialization.data(fromPropertyList: launcherInfo,
                                                      format: .xml,
                                                      options: 0)
        try data.write(to: launcherInfoPlistURL, options: .atomic)
    }

    private func linkLauncherIcon() -> String? {
        let preferredNames = [
            "\(info.primaryIconName).icns",
            "\(info.primaryIconName).png",
            "\(info.primaryIconName)@2x.png",
            "AppIcon.icns",
            "AppIcon60x60@2x.png",
            "AppIcon76x76@2x~ipad.png"
        ]

        for filename in preferredNames {
            let sourceURL = url.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                continue
            }

            let destinationURL = launcherResourcesURL.appendingPathComponent(filename)
            FileManager.default.delete(at: destinationURL)
            try? FileManager.default.createSymbolicLink(at: destinationURL, withDestinationURL: sourceURL)
            return filename
        }

        return nil
    }

    private func shellSingleQuote(_ string: String) -> String {
        "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func writeLauncherScript() throws {
        let playCoverPath = Bundle.main.bundleURL.path
        let executablePath = executable.path
        let launcherScript = """
        #!/bin/zsh
        APP_EXEC=\(shellSingleQuote(executablePath))
        APP_NAME=\(shellSingleQuote(executable.lastPathComponent))

        if pgrep -x "$APP_NAME" > /dev/null 2>&1 || pgrep -f "$APP_EXEC" > /dev/null 2>&1; then
            pkill -TERM -x "$APP_NAME" > /dev/null 2>&1 || true
            pkill -TERM -f "$APP_EXEC" > /dev/null 2>&1 || true
            for _ in {1..5}; do
                if ! pgrep -x "$APP_NAME" > /dev/null 2>&1 && ! pgrep -f "$APP_EXEC" > /dev/null 2>&1; then
                    break
                fi
                sleep 1
            done
            pkill -KILL -x "$APP_NAME" > /dev/null 2>&1 || true
            pkill -KILL -f "$APP_EXEC" > /dev/null 2>&1 || true
            sleep 1
        fi

        if [[ -x "$APP_EXEC" ]]; then
            nohup "$APP_EXEC" > /dev/null 2>&1 &
            disown
            exit 0
        fi

        exec /usr/bin/open -a \(shellSingleQuote(playCoverPath)) \(shellSingleQuote(launcherOpenURL))
        """

        try launcherScript.write(to: launcherExecutableURL, atomically: true, encoding: .utf8)
        try launcherExecutableURL.setBinaryPosixPermissions(0o755)
    }

    private func registerLauncher() {
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        guard FileManager.default.fileExists(atPath: lsregister) else {
            return
        }

        try? Shell.run(print: false, lsregister, "-f", aliasURL.path)
    }

    func loadDiscordIPC() {
        if self.container.doesExist() {
            let appTmp = self.container.containerUrl.appendingPathComponent("Data")
                .appendingPathComponent("tmp")

            try? FileManager.default.createDirectory(at: appTmp, withIntermediateDirectories: false)

            appTmp.enumerateContents { url, _ in
                if url.lastPathComponent.range(of: "discord-ipc-[0-9]", options: .regularExpression) != nil {
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        print("failed to remove discord ipc: \(error)")
                    }
                }
            }

            guard self.settings.settings.discordActivity.enable else {
                return
            }

            let userTmp = FileManager.default.temporaryDirectory.path

            for ipcPort in 0..<10 {
                let socketPath = userTmp + "/discord-ipc-\(ipcPort)"
                if FileManager.default.fileExists(atPath: socketPath) {
                    do {
                        try FileManager.default.createSymbolicLink(atPath: appTmp
                            .appendingPathComponent("discord-ipc-\(ipcPort)").path,
                                                                   withDestinationPath: socketPath)
                        print("Successfully linked discordipc for \(self.info.bundleIdentifier)")
                        return
                    } catch {
                        print(error)
                        continue
                    }
                }
            }

            print("Unable to link discordipc for \(self.info.bundleIdentifier)")
        }
    }

    func createAlias() {
        do {
            try FileManager.default.createDirectory(at: launcherMacOSURL,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            try FileManager.default.createDirectory(at: launcherResourcesURL,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            try writeLauncherInfoPlist()
            try writeLauncherScript()
            registerLauncher()
        } catch {
            Log.shared.log(error.localizedDescription)
        }
    }

    func removeAlias() {
        FileManager.default.delete(at: aliasURL)
    }
}
