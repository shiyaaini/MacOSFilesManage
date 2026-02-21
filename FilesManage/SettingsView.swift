import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("settings.general".localized, systemImage: "gear")
                }
                .tag(0)
            
            AppearanceSettingsView()
                .tabItem {
                    Label("settings.appearance".localized, systemImage: "paintbrush")
                }
                .tag(1)
            
            TerminalSettingsView()
                .tabItem {
                    Label("settings.terminal".localized, systemImage: "terminal")
                }
                .tag(2)
            
            AboutSettingsView()
                .tabItem {
                    Label("settings.about".localized, systemImage: "info.circle")
                }
                .tag(3)
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @State private var selectedLanguage: String = AppPreferences.shared.language
    @State private var rememberWindowState: Bool = AppPreferences.shared.rememberWindowState
    @State private var autoRefreshUI: Bool = AppPreferences.shared.autoRefreshUI
    
    var body: some View {
        Form {
            Section {
                Picker("language.title".localized, selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .onChange(of: selectedLanguage) {
                    AppUIManager.shared.updateLanguage(selectedLanguage)
                }
                
                Toggle("window.rememberState".localized, isOn: $rememberWindowState)
                    .onChange(of: rememberWindowState) {
                        AppPreferences.shared.rememberWindowState = rememberWindowState
                    }
                
                Toggle("common.autoRefreshUI".localized, isOn: $autoRefreshUI)
                    .onChange(of: autoRefreshUI) {
                        AppPreferences.shared.autoRefreshUI = autoRefreshUI
                    }
                
                
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @State private var selectedTheme: String = AppPreferences.shared.theme
    @State private var enableBlur: Bool = AppPreferences.shared.enableBlur
    
    var body: some View {
        Form {
            Section {
                Picker("theme.title".localized, selection: $selectedTheme) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
                .onChange(of: selectedTheme) {
                    AppUIManager.shared.updateTheme(selectedTheme)
                }
                
                Toggle("window.blur".localized, isOn: $enableBlur)
                    .onChange(of: enableBlur) {
                        AppUIManager.shared.applyBlurEffect(enableBlur)
                    }
            }
        }
        .padding()
    }
}

struct TerminalSettingsView: View {
    @State private var terminalOpacity: Double = AppPreferences.shared.terminalOpacity
    @State private var fontSize: Double = 12
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text("terminal.opacity".localized)
                    Slider(value: $terminalOpacity, in: 0.5...1.0, step: 0.05)
                        .onChange(of: terminalOpacity) {
                            AppPreferences.shared.terminalOpacity = terminalOpacity
                        }
                    Text(String(format: "%.0f%%", terminalOpacity * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("terminal.fontSize".localized)
                    Slider(value: $fontSize, in: 10...20, step: 1)
                    Text(String(format: "%.0f pt", fontSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct AboutSettingsView: View {
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("about.title".localized)
                .font(.title)
                .bold()
            Text("about.description".localized)
                .foregroundColor(.secondary)
            Text(String(format: "Version: %@", appVersion))
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("about.github".localized) {
                    if let url = URL(string: "https://github.com/shiyaaini/MacOSFilesManage") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("about.bilibili".localized) {
                    if let url = URL(string: "https://space.bilibili.com/519965290?") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("update.check".localized) {
                    UpdateManager.shared.checkForUpdates(manual: true)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }
}
