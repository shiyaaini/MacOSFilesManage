//
//  FilesManageApp.swift
//  FilesManage
//
//  Created by bolin on 2026/2/13.
//

import SwiftUI

@main
struct FilesManageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1000, height: 600)
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppUIManager.shared.applyInitialSettings()
        
        if let window = NSApplication.shared.windows.first {
            window.applyWindowEffects()
            window.observeEffectChanges()
        }
        
        UpdateManager.shared.checkForUpdates(manual: false)
    }
}
