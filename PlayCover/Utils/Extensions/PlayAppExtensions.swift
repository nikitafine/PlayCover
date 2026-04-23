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
        let bundlePath = url.path
        let executablePath = executable.path
        let launcherScript = """
        #!/bin/zsh
        APP_BUNDLE=\(shellSingleQuote(bundlePath))
        APP_EXEC=\(shellSingleQuote(executablePath))
        APP_ID=\(shellSingleQuote(info.bundleIdentifier))
        POLL_INTERVAL=2
        BACKGROUND_POLLS_TO_KILL=4

        app_phase_for_pid() {
            local pid="$1"
            local info

            info=$(lsappinfo info -app "$pid" 2>/dev/null || true)
            if [[ -z "$info" ]]; then
                printf '%s\\n' 'missing'
            elif printf '%s' "$info" | grep -q 'type="Foreground"'; then
                printf '%s\\n' 'foreground'
            else
                printf '%s\\n' 'background'
            fi
        }

        watch_for_lingering_process() {
            local pid="$1"
            local saw_foreground=0
            local background_polls=0
            local phase
            local watch_lock_dir="/tmp/playcover-watch-${APP_ID}-${pid}"

            if ! mkdir "$watch_lock_dir" 2>/dev/null; then
                return 0
            fi
            trap 'rmdir "$watch_lock_dir" >/dev/null 2>&1 || true' EXIT

            while kill -0 "$pid" > /dev/null 2>&1; do
                phase=$(app_phase_for_pid "$pid")

                if [[ "$phase" == 'foreground' ]]; then
                    saw_foreground=1
                    background_polls=0
                elif [[ "$saw_foreground" -eq 1 ]]; then
                    background_polls=$((background_polls + 1))
                    if [[ "$background_polls" -ge "$BACKGROUND_POLLS_TO_KILL" ]]; then
                        kill -TERM "$pid" > /dev/null 2>&1 || true
                        for _ in {1..5}; do
                            if ! kill -0 "$pid" > /dev/null 2>&1; then
                                return 0
                            fi
                            sleep 1
                        done
                        kill -KILL "$pid" > /dev/null 2>&1 || true
                        return 0
                    fi
                fi

                sleep "$POLL_INTERVAL"
            done
        }

        wait_for_launched_pid() {
            local pid

            for _ in {1..30}; do
                pid=$(pgrep -f "$APP_EXEC" | tail -n1 || true)
                if [[ -n "$pid" ]]; then
                    printf '%s\\n' "$pid"
                    return 0
                fi
                sleep 1
            done

            return 1
        }

        if [[ "${1:-}" == "--watch" && -n "${2:-}" ]]; then
            watch_for_lingering_process "$2"
            exit 0
        fi

        if pgrep -f "$APP_EXEC" > /dev/null 2>&1; then
            pkill -TERM -f "$APP_EXEC" > /dev/null 2>&1 || true
            for _ in {1..5}; do
                if ! pgrep -f "$APP_EXEC" > /dev/null 2>&1; then
                    break
                fi
                sleep 1
            done
            pkill -KILL -f "$APP_EXEC" > /dev/null 2>&1 || true
            sleep 1
        fi

        if [[ -d "$APP_BUNDLE" ]]; then
            if /usr/bin/open "$APP_BUNDLE" --args -ApplePersistenceIgnoreState YES; then
                APP_PID=$(wait_for_launched_pid || true)
                if [[ -n "$APP_PID" ]]; then
                    nohup "$0" --watch "$APP_PID" > /dev/null 2>&1 &
                    disown
                fi
                exit 0
            fi
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
