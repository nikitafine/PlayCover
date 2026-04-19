//
//  Keymapping.swift
//  PlayCover
//
//  Created by TheMoonThatRises on 9/15/25.
//

import Foundation
import UniformTypeIdentifiers

class Keymapping {
    static var keymappingDir: URL {
        let keymappingFolder = PlayTools.playCoverContainer.appendingPathComponent("Keymapping")
        if !FileManager.default.fileExists(atPath: keymappingFolder.path) {
            do {
                try FileManager.default.createDirectory(at: keymappingFolder,
                                                        withIntermediateDirectories: true,
                                                        attributes: [:])
            } catch {
                Log.shared.error(error)
            }
        }
        return keymappingFolder
    }

    let info: AppInfo
    let baseKeymapURL: URL
    let configURL: URL

    let encoder: PropertyListEncoder

    var keymapConfig: KeymapConfig {
        get {
            guard let config = loadConfig() else {
                return resetConfig()
            }
            return config
        }
        set {
            writeConfig(newValue)
        }
    }

    init(_ info: AppInfo) {
        self.info = info

        self.baseKeymapURL = Keymapping.keymappingDir.appendingPathComponent(info.bundleIdentifier)
        self.configURL = baseKeymapURL.appendingPathComponent(".config").appendingPathExtension("plist")

        if !FileManager.default.fileExists(atPath: self.baseKeymapURL.path) {
            do {
                try FileManager.default.createDirectory(at: self.baseKeymapURL,
                                                        withIntermediateDirectories: true)
            } catch {
                Log.shared.error(error)
            }
        }

        self.encoder = PropertyListEncoder()
        self.encoder.outputFormat = .xml

        self.reloadKeymapCache()

    }

    private func constructKeymapPath(name: String) -> URL {
        baseKeymapURL.appendingPathComponent(name).appendingPathExtension("plist")
    }

    public func reloadKeymapCache() {
        guard FileManager.default.fileExists(atPath: baseKeymapURL.path) else {
            return
        }

        do {
            let directoryContents = try FileManager.default
                .contentsOfDirectory(at: baseKeymapURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            var keymaps: [URL] = []

            if directoryContents.count > 0 {
                for keymap in directoryContents where keymap.pathExtension.contains("plist") {
                    if !keymapConfig.keymapOrder.contains(keymap) {
                        keymapConfig.keymapOrder.append(keymap)
                    }

                    keymaps.append(keymap)
                }

                for keymap in keymapConfig.keymapOrder where !keymaps.contains(keymap) {
                    setKeymap(name: keymap.deletingPathExtension().lastPathComponent,
                              map: Keymap(bundleIdentifier: info.bundleIdentifier))
                }

                return
            }
        } catch {
            Log.shared.log("Failed to get keymapping directory at \(baseKeymapURL.path)", isError: true)
            Log.shared.error(error)
        }

        setKeymap(name: "default", map: Keymap(bundleIdentifier: info.bundleIdentifier))
        reloadKeymapCache()
    }

    public func getKeymap(name: String) -> Keymap {
        let keymapURL = constructKeymapPath(name: name)
        guard let keymap = loadKeymap(at: keymapURL) else {
            return reset(name: name)
        }
        return keymap
    }

    public func createEmptyKeymap(name: String) -> Bool {
        setKeymap(name: name, map: Keymap(bundleIdentifier: info.bundleIdentifier))

        return hasKeymap(name: name)
    }

    private func setKeymap(name: String, map: Keymap) {
        let keymapPath = constructKeymapPath(name: name)

        do {
            let data = try encoder.encode(map)
            try data.write(to: keymapPath)

            if !keymapConfig.keymapOrder.contains(keymapPath) {
                keymapConfig.keymapOrder.append(keymapPath)
            }
        } catch {
            Log.shared.log("Failed to write keymap at \(keymapPath.path)", isError: true)
        }
    }

    public func renameKeymap(prevName: String, newName: String) -> Bool {
        let oldPath = constructKeymapPath(name: prevName)
        let newPath = constructKeymapPath(name: newName)

        if let oldKeymapIndex = keymapConfig.keymapOrder.firstIndex(of: oldPath) {
            do {
                try FileManager.default.moveItem(at: oldPath, to: newPath)

                keymapConfig.keymapOrder[oldKeymapIndex] = newPath

                return true
            } catch {
                Log.shared.error(error)
                return false
            }
        } else {
            Log.shared.log("Could not find keymap with name: \(prevName)", isError: true)
            return false
        }
    }

    public func deleteKeymap(name: String) -> Bool {
        let keymapURL = constructKeymapPath(name: name)

        if let keymapIndex = keymapConfig.keymapOrder.firstIndex(of: keymapURL) {
            do {
                try FileManager.default.trashItem(at: keymapURL, resultingItemURL: nil)

                keymapConfig.keymapOrder.remove(at: keymapIndex)

                return true
            } catch {
                Log.shared.error(error)
                return false
            }
        } else {
            Log.shared.log("Could not find keymap with name: \(name)", isError: true)
            return false
        }
    }

    public func hasKeymap(name: String) -> Bool {
        keymapConfig.keymapOrder.contains(constructKeymapPath(name: name))
    }

    @discardableResult
    public func reset(name: String) -> Keymap {
        let keymap = Keymap(bundleIdentifier: info.bundleIdentifier)
        setKeymap(name: name, map: keymap)
        return keymap
    }

    @discardableResult
    private func resetConfig() -> KeymapConfig {
        let config = defaultConfig()
        writeConfig(config)
        return config
    }

    private func loadConfig() -> KeymapConfig? {
        do {
            let data = try Data(contentsOf: configURL)
            return try PropertyListDecoder().decode(KeymapConfig.self, from: data)
        } catch {
            Log.shared.log("Failed to load keymap config at \(configURL.path)", isError: true)
            return nil
        }
    }

    private func writeConfig(_ config: KeymapConfig) {
        do {
            let data = try encoder.encode(config)
            try data.write(to: configURL)
        } catch {
            Log.shared.log("Failed to write keymap config at \(configURL.path)", isError: true)
        }
    }

    private func defaultConfig() -> KeymapConfig {
        let defaultURL = constructKeymapPath(name: "default")
        return KeymapConfig(defaultKm: defaultURL, keymapOrder: [defaultURL])
    }

    private func loadKeymap(at url: URL) -> Keymap? {
        do {
            let data = try Data(contentsOf: url)
            return try PropertyListDecoder().decode(Keymap.self, from: data)
        } catch {
            Log.shared.log("Failed to load keymap at \(url.path)", isError: true)
            return nil
        }
    }

    public func importKeymap(name: String, success: @escaping (Bool) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = true
        openPanel.allowedContentTypes = [UTType(exportedAs: "io.playcover.PlayCover-playmap")]
        openPanel.title = NSLocalizedString("playapp.importKm", comment: "")

        openPanel.begin { result in
            if result == .OK {
                do {
                    if let selectedPath = openPanel.url {
                        let data = try Data(contentsOf: selectedPath)
                        let importedKeymap = try PropertyListDecoder().decode(Keymap.self, from: data)
                        if importedKeymap.bundleIdentifier == self.info.bundleIdentifier {
                            self.setKeymap(name: name, map: importedKeymap)
                            success(true)
                        } else {
                            if self.differentBundleIdKeymapAlert() {
                                self.setKeymap(name: name, map: importedKeymap)
                                success(true)
                            } else {
                                success(false)
                            }
                        }
                    }
                } catch {
                    if let selectedPath = openPanel.url {
                        if let keymap = LegacySettings.convertLegacyKeymapFile(selectedPath) {
                            if keymap.bundleIdentifier == self.info.bundleIdentifier {
                                self.setKeymap(name: name, map: keymap)
                                success(true)
                            } else {
                                if self.differentBundleIdKeymapAlert() {
                                    self.setKeymap(name: name, map: keymap)
                                    success(true)
                                } else {
                                    success(false)
                                }
                            }
                        } else {
                            success(false)
                        }
                    }
                }
                openPanel.close()
            }
        }
    }

    public func exportKeymap(name: String) {
        let savePanel = NSSavePanel()
        savePanel.title = NSLocalizedString("playapp.exportKm", comment: "")
        savePanel.nameFieldLabel = NSLocalizedString("playapp.exportKmPanel.fieldLabel", comment: "")
        savePanel.nameFieldStringValue = info.displayName
        savePanel.allowedContentTypes = [UTType(exportedAs: "io.playcover.PlayCover-playmap")]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        savePanel.begin { result in
            if result == .OK {
                do {
                    if let selectedPath = savePanel.url {
                        let data = try self.encoder.encode(self.getKeymap(name: name))
                        try data.write(to: selectedPath)
                        selectedPath.openInFinder()
                    }
                } catch {
                    savePanel.close()
                    Log.shared.error(error)
                }
                savePanel.close()
            }
        }
    }

    private func differentBundleIdKeymapAlert() -> Bool {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("alert.differentBundleIdKeymap.message", comment: "")
        alert.informativeText = NSLocalizedString("alert.differentBundleIdKeymap.text", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("button.Proceed", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("button.Cancel", comment: ""))

        return alert.runModal() == .alertFirstButtonReturn
    }
}
