
import Foundation
import AppKit
import Combine

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var hasUpdate: Bool = false
    @Published var latestVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var releaseURL: URL?
    
    private let repoOwner = "shiyaaini"
    private let repoName = "MacOSFilesManage"
    
    private var releaseAPI: URL? {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")
    }
    
    func checkForUpdates(manual: Bool = false) {
        guard let url = releaseAPI else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Update check failed: \(error.localizedDescription)")
                if manual {
                    DispatchQueue.main.async { self.showErrorAlert(error.localizedDescription) }
                }
                return
            }
            
            guard let data = data else {
                if manual {
                    DispatchQueue.main.async { self.showErrorAlert("No data received") }
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let tagName = json["tag_name"] as? String {
                    
                    // Strip 'v' prefix if present (e.g., v1.0.1 -> 1.0.1)
                    let version = tagName.lowercased().hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                    
                    print("Latest version: \(version), Current: \(currentVersion)")
                    
                    if self.isVersion(version, newerThan: currentVersion) {
                        let skipped = UserDefaults.standard.string(forKey: "skippedVersion")
                        if !manual && skipped == version {
                            return
                        }
                        
                        let body = json["body"] as? String ?? ""
                        let htmlUrl = json["html_url"] as? String
                        
                        DispatchQueue.main.async {
                            self.hasUpdate = true
                            self.latestVersion = version
                            self.releaseNotes = body
                            if let urlStr = htmlUrl {
                                self.releaseURL = URL(string: urlStr)
                            }
                            self.showUpdateAlert(version: version, manual: manual)
                        }
                    } else {
                        if manual {
                            DispatchQueue.main.async { self.showNoUpdateAlert() }
                        }
                    }
                } else {
                    if manual {
                        DispatchQueue.main.async { self.showErrorAlert("Invalid response format") }
                    }
                }
            } catch {
                if manual {
                    DispatchQueue.main.async { self.showErrorAlert(error.localizedDescription) }
                }
            }
        }
        task.resume()
    }
    
    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        return v1.compare(v2, options: .numeric) == .orderedDescending
    }
    
    private func showUpdateAlert(version: String, manual: Bool) {
        let alert = NSAlert()
        alert.messageText = "update.available.title".localized
        alert.informativeText = String(format: "update.available.message".localized, version)
        alert.addButton(withTitle: "update.download".localized)
        
        if manual {
            alert.addButton(withTitle: "common.cancel".localized)
        } else {
            alert.addButton(withTitle: "update.ignore".localized)
            alert.addButton(withTitle: "common.cancel".localized)
        }
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = releaseURL {
                NSWorkspace.shared.open(url)
            }
        } else if !manual && response == .alertSecondButtonReturn {
            UserDefaults.standard.set(version, forKey: "skippedVersion")
        }
    }
    
    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "update.latest.title".localized
        alert.informativeText = "update.latest.message".localized
        alert.addButton(withTitle: "common.ok".localized)
        alert.runModal()
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "common.ok".localized)
        alert.runModal()
    }
}
