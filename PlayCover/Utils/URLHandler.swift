//
//  URIHandler.swift
//  PlayCover
//
//  Created by Venti on 14/02/2023.
//

import Foundation

enum URLTypes: Int, Equatable {
    case source
    case keymap
    case app
}

enum URLAction: Int, Equatable {
    case add
    case remove
    case update
    case install
    case open
}

class URLObservable: ObservableObject {
    @Published var url: String?
    @Published var type: URLTypes?
    @Published var action: URLAction?

    public static var shared = URLObservable()
}

struct URLHandler {
    public static var shared = URLHandler()

    func processURL(url: URL) {
        guard let urlComponenents = NSURLComponents(url: url, resolvingAgainstBaseURL: false),
              let uriHost = urlComponenents.host,
              let params = urlComponenents.queryItems else {
                // Fall back to old url handler (for files)
                if url.pathExtension == "ipa" {
                    Installer.install(ipaUrl: url, export: false, returnCompletion: { _ in
                    Task { @MainActor in
                        AppsVM.shared.fetchApps()
                        NotifyService.shared.notify(
                            NSLocalizedString("notification.appInstalled", comment: ""),
                            NSLocalizedString("notification.appInstalled.message", comment: "")
                        )
                    }})
                }
                return
            }
        // URI format: playcoverapp://<object>?action=<action>&<param>=<value>
        // Example: playcoverapp://source?action=add&url=https://homebrew.playcover.io
        // Switch case for main uri path
        switch uriHost {
        case "source":
            processSourceURL(params: params)
        case "app":
            processAppURL(params: params)
        default:
            // Print URL to log and break
            NSLog("Unknown URL: \(url)")
        }
    }

    func processSourceURL(params: [URLQueryItem]) {
        // Make dang sure we have the params we need and they match expected query items
        guard params.count == 2,
              params[0].name == "action",
              params[1].name == "url" else {
            // Print params to logs and break
            NSLog("Unknown source URL params: \(params)")
            return
        }

        if let actionParam = params[0].value {
            URLObservable.shared.type = .source
            switch actionParam {
            case "add":
                // Add source
                if let url = params[1].value {
                    URLObservable.shared.url = url
                    URLObservable.shared.action = .add
                }
            case "remove":
                // Remove source
                if let url = params[1].value {
                    URLObservable.shared.url = url
                    URLObservable.shared.action = .remove
                }
            case "update":
                // Update source
                if let url = params[1].value {
                    URLObservable.shared.url = url
                    URLObservable.shared.action = .update
                }
            default:
                // Print params to console and break
                print("Unknown source URL params: \(params)")
            }
        }
    }

    func processAppURL(params: [URLQueryItem]) {
        guard let action = params.first(where: { $0.name == "action" })?.value else {
            NSLog("Missing app action in params: \(params)")
            return
        }

        switch action {
        case "open":
            guard let bundleId = params.first(where: { $0.name == "bundleId" })?.value,
                  !bundleId.isEmpty else {
                NSLog("Missing bundleId for app open URL: \(params)")
                return
            }

            Task { @MainActor in
                await openApp(bundleId: bundleId)
            }
        default:
            NSLog("Unknown app URL params: \(params)")
        }
    }

    @MainActor
    private func openApp(bundleId: String) async {
        AppsVM.shared.fetchApps()

        for _ in 0..<50 {
            if let app = AppsVM.shared.apps.first(where: { $0.info.bundleIdentifier == bundleId }) {
                if !app.isStarting {
                    await app.launch(viaLauncherAlias: true)
                }
                return
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        NSLog("Unable to find app with bundle id: \(bundleId)")
    }
}
