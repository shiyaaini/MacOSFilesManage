
import Foundation
import AppKit
import Combine

struct LaunchAgentItem: Identifiable, Equatable {
    let id: UUID = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
    var label: String? {
        guard let dict = NSDictionary(contentsOf: url),
              let lbl = dict["Label"] as? String else { return nil }
        return lbl
    }
}

class LaunchAgentManager: ObservableObject {
    @Published var agents: [LaunchAgentItem] = []
    
    private let agentsURL: URL? = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("LaunchAgents")
    }()
    
    func fetchAgents() {
        guard let url = agentsURL else { return }
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let plistFiles = urls.filter { $0.pathExtension == "plist" }
            DispatchQueue.main.async {
                self.agents = plistFiles.map { LaunchAgentItem(url: $0) }
            }
        } catch {
            print("Error fetching launch agents: \(error)")
            DispatchQueue.main.async {
                self.agents = []
            }
        }
    }
    
    func deleteAgent(_ item: LaunchAgentItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            fetchAgents()
        } catch {
            print("Error deleting agent: \(error)")
        }
    }
    
    func openInFinder(_ item: LaunchAgentItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    func toggleDisabled(_ item: LaunchAgentItem) {
        // Simple toggle by renaming to .disabled or back
        let isDisabled = item.url.pathExtension == "disabled"
        let newURL: URL
        if isDisabled {
            newURL = item.url.deletingPathExtension() // Remove .disabled
        } else {
            newURL = item.url.appendingPathExtension("disabled")
        }
        
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            fetchAgents()
        } catch {
            print("Error toggling agent: \(error)")
        }
    }
}
