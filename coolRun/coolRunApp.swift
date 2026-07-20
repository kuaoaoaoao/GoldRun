//
//  coolRunApp.swift
//  coolRun
//
//  Created by kuao on 2026/5/21.
//

import SwiftUI

private let posthogApiKey = "phc_ADRxZPgBzDQVUTZELLGfCFU4uisGEh9zFBUNZD3cjkjU"
private let posthogHost = "https://us.i.posthog.com"

@main
struct coolRunApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    init() {
        Analytics.configure(
            projectToken: ProcessInfo.processInfo.environment["POSTHOG_API_KEY"] ?? posthogApiKey,
            host: ProcessInfo.processInfo.environment["POSTHOG_HOST"] ?? posthogHost,
            enabled: AppSettings.shared.analyticsEnabled
        )
    }

    var body: some Scene {
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}
