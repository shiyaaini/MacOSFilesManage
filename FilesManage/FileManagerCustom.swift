import Foundation
import AppKit
import UniformTypeIdentifiers
import Combine

class FileManager_Custom: ObservableObject {
    @Published var currentPath: URL
    @Published var files: [FileItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pathHistory: [URL] = []
    @Published var historyIndex: Int = -1
    @Published var isProcessing = false
    @Published var processingTitle: String = ""
    @Published var processingProgress: Double?
    @Published var processingDetail: String = ""
    
    // Archive Navigation State
    @Published var isInsideArchive: Bool = false
    @Published var currentArchiveURL: URL?
    @Published var currentArchiveInternalPath: String = ""
    
    static var sharedClipboardItems: [URL] = []
    static var sharedClipboardCut: Bool = false
    
    private let fileManager = FileManager.default
    private let loadQueue = DispatchQueue(label: "FilesManage.load.queue", qos: .userInitiated)
    private var loadWorkItem: DispatchWorkItem?
    private var processingProcess: Process?
    private var progressTimer: DispatchSourceTimer?
    
    init() {
        self.currentPath = fileManager.homeDirectoryForCurrentUser
        loadFiles()
    }
    
    func loadFiles() {
        isLoading = true
        errorMessage = nil
        let target = currentPath
        loadWorkItem?.cancel()
        
        // Archive Mode
        if isInsideArchive, let archiveURL = currentArchiveURL {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.loadWorkItem?.isCancelled == true { return }
                
                let entries = ArchiveManager.shared.listContents(of: archiveURL)
                
                var items: [FileItem] = []
                // Clean up internal path to match entry format (no leading slash, maybe trailing slash handling)
                // Entries usually don't have leading slash if relative.
                // My ArchiveManager returns paths like "folder/" or "file.txt" or "folder/file.txt".
                
                let currentPrefix = self.currentArchiveInternalPath.isEmpty ? "" : self.currentArchiveInternalPath + "/"
                var processedDirs: Set<String> = []
                
                for entry in entries {
                    // Check if entry is inside current internal path
                    // Entry path: "folder/sub/file.txt"
                    // currentPrefix: "folder/"
                    
                    if entry.path.hasPrefix(currentPrefix) {
                        let relative = String(entry.path.dropFirst(currentPrefix.count))
                        if relative.isEmpty { continue }
                        
                        let components = relative.split(separator: "/")
                        if components.count == 1 {
                            // Direct child
                            // If entry is "folder/sub/" (directory), relative is "sub/"
                            // split gives ["sub"]
                            // We should show it.
                            // If entry is "folder/file.txt", relative is "file.txt" -> show.
                            items.append(FileItem(archiveEntry: entry, archiveURL: archiveURL))
                        } else {
                            // Subdirectory content not explicitly listed as directory entry
                            // e.g. entry is "folder/sub/file.txt" but "folder/sub/" might not exist as entry
                            let dirName = String(components[0])
                            if !processedDirs.contains(dirName) {
                                processedDirs.insert(dirName)
                                let dirPath = currentPrefix + dirName
                                // Construct a virtual directory entry
                                let dirEntry = ArchiveEntry(path: dirPath, isDirectory: true, size: 0, modifiedDate: nil)
                                items.append(FileItem(archiveEntry: dirEntry, archiveURL: archiveURL))
                            }
                        }
                    }
                }
                
                // Deduplicate items (ArchiveEntry might list "folder/" and we also inferred it from "folder/file.txt")
                // Use dictionary keyed by name
                var uniqueItems: [String: FileItem] = [:]
                for item in items {
                    uniqueItems[item.name] = item
                }
                items = Array(uniqueItems.values)
                
                items = items.sorted { item1, item2 in
                    if item1.isDirectory != item2.isDirectory {
                        return item1.isDirectory
                    }
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
                
                DispatchQueue.main.async {
                    if self.currentPath == target {
                        self.files = items
                        self.isLoading = false
                        self.errorMessage = nil
                    }
                }
            }
            loadWorkItem = workItem
            loadQueue.async(execute: workItem)
            return
        }
        
        // Standard Mode
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.loadWorkItem?.isCancelled == true { return }
            do {
                let contents = try self.fileManager.contentsOfDirectory(
                    at: target,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                if self.loadWorkItem?.isCancelled == true { return }
                var items = contents.map { FileItem(url: $0) }
                items = items.sorted { item1, item2 in
                    if item1.isDirectory != item2.isDirectory {
                        return item1.isDirectory
                    }
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
                DispatchQueue.main.async {
                    if self.currentPath == target {
                        self.files = items
                        self.isLoading = false
                        self.errorMessage = nil
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    let nsError = error as NSError
                    if nsError.domain == NSCocoaErrorDomain &&
                       (nsError.code == NSFileReadNoPermissionError || nsError.code == 257) {
                        self.errorMessage = "file.permission.denied".localized
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                    if self.currentPath == target {
                        self.files = []
                        self.isLoading = false
                    }
                }
            }
        }
        loadWorkItem = workItem
        loadQueue.async(execute: workItem)
    }
    
    func navigateTo(_ url: URL) {
        guard currentPath != url else { return }
        
        // History management
        if historyIndex < pathHistory.count - 1 {
            pathHistory.removeSubrange((historyIndex + 1)...)
        }
        pathHistory.append(currentPath)
        historyIndex = pathHistory.count - 1
        
        // Determine state based on URL
        if ArchiveManager.shared.isSupportedArchive(url) {
            isInsideArchive = true
            currentArchiveURL = url
            currentArchiveInternalPath = ""
            currentPath = url
            loadFiles()
            return
        }
        
        if isInsideArchive, let archiveURL = currentArchiveURL, url.path.hasPrefix(archiveURL.path) {
            let base = archiveURL.path
            let suffix = String(url.path.dropFirst(base.count))
            currentArchiveInternalPath = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            currentPath = url
            loadFiles()
            return
        }
        
        // Check if we are entering an archive from outside (virtual URL passed directly?)
        // Or if we need to exit archive mode
        
        // Check if url is a real directory
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            isInsideArchive = false
            currentArchiveURL = nil
            currentArchiveInternalPath = ""
            currentPath = url
            loadFiles()
            return
        }
        
        // If URL doesn't exist, maybe it's a virtual archive path we jumped to?
        // Check components
        var temp = url
        while temp.pathComponents.count > 1 {
            if ArchiveManager.shared.isSupportedArchive(temp) {
                isInsideArchive = true
                currentArchiveURL = temp
                let base = temp.path
                let suffix = String(url.path.dropFirst(base.count))
                currentArchiveInternalPath = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                currentPath = url
                loadFiles()
                return
            }
            temp = temp.deletingLastPathComponent()
        }
        
        // Fallback (likely error or non-existent path)
        isInsideArchive = false
        currentPath = url
        loadFiles()
    }
    
    
    func goBack() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        let url = pathHistory[historyIndex]
        restoreState(from: url)
    }
    
    func goForward() {
        guard historyIndex < pathHistory.count - 1 else { return }
        historyIndex += 1
        let url = pathHistory[historyIndex]
        restoreState(from: url)
    }
    
    private func restoreState(from url: URL) {
        // Similar to navigateTo but without modifying history
        if ArchiveManager.shared.isSupportedArchive(url) {
            isInsideArchive = true
            currentArchiveURL = url
            currentArchiveInternalPath = ""
            currentPath = url
            loadFiles()
            return
        }
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            isInsideArchive = false
            currentArchiveURL = nil
            currentArchiveInternalPath = ""
            currentPath = url
            loadFiles()
            return
        }
        
        var temp = url
        while temp.pathComponents.count > 1 {
            if ArchiveManager.shared.isSupportedArchive(temp) {
                isInsideArchive = true
                currentArchiveURL = temp
                let base = temp.path
                let suffix = String(url.path.dropFirst(base.count))
                currentArchiveInternalPath = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                currentPath = url
                loadFiles()
                return
            }
            temp = temp.deletingLastPathComponent()
        }
        
        isInsideArchive = false
        currentPath = url
        loadFiles()
    }
    
    func goUp() {
        let parent = currentPath.deletingLastPathComponent()
        guard parent != currentPath else { return }
        navigateTo(parent)
    }
    
    func goHome() {
        navigateTo(fileManager.homeDirectoryForCurrentUser)
    }
    
    func openFile(_ item: FileItem) {
        if item.url.pathExtension.lowercased() == "app" {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: item.url, configuration: config, completionHandler: nil)
        } else if item.isDirectory {
            navigateTo(item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }
    
    var canPaste: Bool {
        if !FileManager_Custom.sharedClipboardItems.isEmpty { return true }
        return !pasteboardFileURLs().isEmpty
    }
    
    private func writeFileURLsToPasteboard(_ urls: [URL]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls.map { $0 as NSURL })
    }
    
    func writeFileURLsToDragPasteboard(_ urls: [URL]) {
        let pb = NSPasteboard(name: .drag)
        pb.clearContents()
        pb.writeObjects(urls.map { $0 as NSURL })
    }
    
    func copyToClipboard(_ item: FileItem) {
        FileManager_Custom.sharedClipboardItems = [item.url]
        FileManager_Custom.sharedClipboardCut = false
        writeFileURLsToPasteboard([item.url])
    }
    
    func copyToClipboard(_ items: [FileItem]) {
        FileManager_Custom.sharedClipboardItems = items.map { $0.url }
        FileManager_Custom.sharedClipboardCut = false
        writeFileURLsToPasteboard(items.map { $0.url })
    }
    
    func cutToClipboard(_ item: FileItem) {
        FileManager_Custom.sharedClipboardItems = [item.url]
        FileManager_Custom.sharedClipboardCut = true
        writeFileURLsToPasteboard([item.url])
    }
    
    func cutToClipboard(_ items: [FileItem]) {
        FileManager_Custom.sharedClipboardItems = items.map { $0.url }
        FileManager_Custom.sharedClipboardCut = true
        writeFileURLsToPasteboard(items.map { $0.url })
    }
    
    func pasteClipboard() {
        if !FileManager_Custom.sharedClipboardItems.isEmpty {
            processPaste(sources: FileManager_Custom.sharedClipboardItems, move: FileManager_Custom.sharedClipboardCut)
            if FileManager_Custom.sharedClipboardCut {
                FileManager_Custom.sharedClipboardItems = []
                FileManager_Custom.sharedClipboardCut = false
            }
            return
        }
        
        let pbURLs = pasteboardFileURLs()
        guard !pbURLs.isEmpty else { return }
        processPaste(sources: pbURLs, move: false)
    }
    
    private func processPaste(sources: [URL], move: Bool) {
        let destDir = currentPath
        // Pre-calculate destinations to avoid collisions
        var tasks: [(src: URL, dst: URL)] = []
        for src in sources {
            let name = src.lastPathComponent
            var dest = destDir.appendingPathComponent(name)
            if fileManager.fileExists(atPath: dest.path) {
                let base = src.deletingPathExtension().lastPathComponent
                let ext = src.pathExtension.isEmpty ? nil : src.pathExtension
                dest = uniqueURL(in: destDir, baseName: base, ext: ext)
            }
            tasks.append((src, dest))
        }
        
        if move {
            performMove(tasks)
        } else {
            performCopy(tasks)
        }
    }
    
    private func performCopy(_ tasks: [(src: URL, dst: URL)]) {
        let totalBytes = tasks.reduce(0) { $0 + totalSize(of: $1.src) }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingTitle = "progress.copying".localized
            self.processingProgress = 0
            self.processingDetail = ""
        }
        
        // Use a background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Start a timer to monitor destination size
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now(), repeating: .milliseconds(200))
            timer.setEventHandler {
                var currentBytes: Int64 = 0
                for task in tasks {
                    currentBytes += self.totalSize(of: task.dst)
                }
                let pr = totalBytes > 0 ? Double(currentBytes) / Double(totalBytes) : 0
                DispatchQueue.main.async {
                    self.processingProgress = min(1.0, pr)
                }
            }
            timer.resume()
            self.progressTimer = timer
            
            for task in tasks {
                DispatchQueue.main.async { self.processingDetail = task.src.lastPathComponent }
                
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                // -v for verbose? No need if we check size. --rsrc to preserve resource forks/metadata
                p.arguments = ["--rsrc", task.src.path, task.dst.path]
                p.environment = ["LC_ALL": "C", "LANG": "C"]
                
                try? p.run()
                p.waitUntilExit()
            }
            
            timer.cancel()
            self.progressTimer = nil
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processingProgress = nil
                self.processingDetail = ""
                self.processingTitle = ""
                self.loadFiles()
            }
        }
    }
    
    private func performMove(_ tasks: [(src: URL, dst: URL)]) {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingTitle = "progress.moving".localized
            self.processingProgress = nil // Indeterminate
            self.processingDetail = ""
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            for task in tasks {
                DispatchQueue.main.async { self.processingDetail = task.src.lastPathComponent }
                do {
                    try self.fileManager.moveItem(at: task.src, to: task.dst)
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processingProgress = nil
                self.processingDetail = ""
                self.processingTitle = ""
                self.loadFiles()
            }
        }
    }
    
    private func pasteboardFileURLs() -> [URL] {
        var urls: [URL] = []
        let pb = NSPasteboard.general
        if let items = pb.pasteboardItems {
            for it in items {
                if let s = it.string(forType: .fileURL), let u = URL(string: s) {
                    urls.append(u)
                } else if let s = it.string(forType: .URL), let u = URL(string: s), u.isFileURL {
                    urls.append(u)
                } else if let s = it.string(forType: .string) {
                    let lines = s.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    for line in lines where !line.isEmpty {
                        let p = URL(fileURLWithPath: line)
                        if fileManager.fileExists(atPath: p.path) {
                            urls.append(p)
                        }
                    }
                }
            }
        }
        return urls
    }
    
    func copyPath(_ item: FileItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.url.path, forType: .string)
    }
    
    func copyPaths(_ items: [FileItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let text = items.map { $0.url.path }.joined(separator: "\n")
        pb.setString(text, forType: .string)
    }
    
    private func confirmMoveToTrash(_ items: [FileItem]) -> Bool {
        let alert = NSAlert()
        alert.messageText = "file.trash.confirm.title".localized
        if items.count == 1 {
            alert.informativeText = String(format: "file.trash.confirm.single".localized, items[0].name)
        } else {
            alert.informativeText = String(format: "file.trash.confirm.multi".localized, items.count)
        }
        alert.addButton(withTitle: "common.ok".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        let response: NSApplication.ModalResponse
        if Thread.isMainThread {
            response = alert.runModal()
        } else {
            var r = NSApplication.ModalResponse.cancel
            DispatchQueue.main.sync { r = alert.runModal() }
            response = r
        }
        return response == .alertFirstButtonReturn
    }
    
    func moveToTrash(_ item: FileItem) {
        moveToTrash([item])
    }
    
    func moveToTrash(_ items: [FileItem]) {
        guard !items.isEmpty else { return }
        guard confirmMoveToTrash(items) else { return }
        
        if isInsideArchive, let archiveURL = currentArchiveURL {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isProcessing = true
                    self.processingTitle = "progress.deleting".localized
                    self.processingProgress = nil
                }
                
                for item in items {
                    let archivePath = archiveURL.path
                    let itemPath = item.url.path
                    if itemPath.hasPrefix(archivePath) {
                        var entryPath = String(itemPath.dropFirst(archivePath.count))
                        if entryPath.hasPrefix("/") { entryPath.removeFirst() }
                        // For folders, zip -d folder/* might be needed?
                        // zip -d archive.zip entry
                        // If entry is directory, we might need recursive delete or wildcard.
                        // zip usually handles directory entries if they exist.
                        // But if we delete "folder/", does it delete contents?
                        // zip -d archive.zip "folder/*"
                        if item.isDirectory {
                            ArchiveManager.shared.delete(entryPath + "/*", from: archiveURL)
                            ArchiveManager.shared.delete(entryPath + "/", from: archiveURL) // delete dir entry itself
                        } else {
                            ArchiveManager.shared.delete(entryPath, from: archiveURL)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.processingTitle = ""
                    self.loadFiles()
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingTitle = "progress.trashing".localized
            self.processingProgress = 0
            self.processingDetail = ""
        }
        
        let total = Double(items.count)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var failed: [String] = []
            var processed = 0
            
            for it in items {
                DispatchQueue.main.async {
                    self.processingDetail = it.name
                }
                
                do {
                    try self.fileManager.trashItem(at: it.url, resultingItemURL: nil)
                } catch {
                    failed.append(it.name)
                }
                
                processed += 1
                let pr = Double(processed) / total
                DispatchQueue.main.async {
                    self.processingProgress = pr
                }
                // Small delay to make progress visible for very few items, or just let it fly
                // Thread.sleep(forTimeInterval: 0.05) 
            }
            
            DispatchQueue.main.async {
                if !failed.isEmpty {
                    self.errorMessage = "file.trash.failedPrefix".localized + failed.joined(separator: ", ")
                }
                self.isProcessing = false
                self.processingProgress = nil
                self.processingDetail = ""
                self.processingTitle = ""
                self.loadFiles()
            }
        }
    }
    
    func openTerminal(at item: FileItem) {
        let target = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
        let path = target.path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            do script "cd \\\"\(path)\\\""
            activate
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            do {
                try p.run()
                p.waitUntilExit()
                if p.terminationStatus != 0 {
                    let iTermScript = """
                    tell application "iTerm"
                        activate
                        try
                            create window with default profile
                            tell current session of current window
                                write text "cd \\\"\(path)\\\""
                            end tell
                        on error
                            create window with default profile
                            tell current session of current window
                                write text "cd \\\"\(path)\\\""
                            end tell
                        end try
                    end tell
                    """
                    let ip = Process()
                    ip.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    ip.arguments = ["-e", iTermScript]
                    try? ip.run()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func openWith(_ item: FileItem) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let appURL = panel.url {
                NSWorkspace.shared.open([item.url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
        }
    }
    
    func getApplications(for item: FileItem) -> [URL] {
        return NSWorkspace.shared.urlsForApplications(toOpen: item.url)
    }
    
    func getDefaultApplication(for item: FileItem) -> URL? {
        return NSWorkspace.shared.urlForApplication(toOpen: item.url)
    }
    
    func setDefaultApplication(at appURL: URL, for item: FileItem) {
        if let type = try? item.url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    func openWithSetDefault(_ item: FileItem) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "openWith.setDefault.prompt".localized
        panel.begin { response in
            if response == .OK, let appURL = panel.url {
                self.setDefaultApplication(at: appURL, for: item)
            }
        }
    }
    
    private func totalSize(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue {
            var sum: Int64 = 0
            if let en = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles], errorHandler: nil) {
                for case let u as URL in en {
                    let attrs = try? fileManager.attributesOfItem(atPath: u.path)
                    let s = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                    sum += s
                }
            }
            return max(1, sum)
        } else {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            let s = (attrs?[.size] as? NSNumber)?.int64Value ?? 1
            return max(1, s)
        }
    }
    
    func compress(_ item: FileItem, to destination: URL? = nil) {
        let dir = item.url.deletingLastPathComponent()
        let base = item.url.deletingPathExtension().lastPathComponent
        let dest: URL
        if let d = destination {
            dest = d
        } else {
            var candidate = dir.appendingPathComponent(base + ".zip")
            var i = 2
            while fileManager.fileExists(atPath: candidate.path) {
                candidate = dir.appendingPathComponent("\(base) \(i).zip")
                i += 1
            }
            dest = candidate
        }
        
        let totalBytes = totalSize(of: item.url)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        // If destination is custom, we might need to handle parent directory if different
        let destDir = dest.deletingLastPathComponent()
        p.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", item.url.path, dest.path]
        // p.currentDirectoryURL = dir // ditto handles absolute paths fine
        p.environment = (ProcessInfo.processInfo.environment.merging(["LC_ALL": "C", "LANG": "C"], uniquingKeysWith: { _, new in new }))
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingTitle = "progress.compress".localized
            self.processingProgress = 0
            self.processingDetail = base
        }
        processingProcess = p
        progressTimer?.cancel()
        progressTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        progressTimer?.schedule(deadline: .now(), repeating: .milliseconds(200))
        progressTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let attrs = try? self.fileManager.attributesOfItem(atPath: dest.path)
            let written = (attrs?[.size] as? NSNumber)?.doubleValue ?? 0
            let pr = max(0.0, min(1.0, written / Double(totalBytes)))
            DispatchQueue.main.async {
                self.processingProgress = pr
            }
        }
        progressTimer?.resume()
        DispatchQueue.global(qos: .userInitiated).async {
            try? p.run()
            p.waitUntilExit()
            self.progressTimer?.cancel()
            self.progressTimer = nil
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processingProgress = nil
                self.processingDetail = ""
                self.processingTitle = ""
                self.processingProcess = nil
                self.loadFiles()
            }
        }
    }
    
    func compressAs(_ item: FileItem) {
        let panel = NSSavePanel()
        panel.title = "menu.compressTo".localized
        panel.nameFieldStringValue = item.url.deletingPathExtension().lastPathComponent + ".zip"
        panel.allowedContentTypes = [UTType.zip]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.compress(item, to: url)
            }
        }
    }
    
    func decompress(_ items: [FileItem], to destination: URL? = nil) {
        let supported = items.filter { ArchiveManager.shared.isSupportedArchive($0.url) }
        guard !supported.isEmpty else { return }
        
        var missingDeps: Set<String> = []
        for item in supported {
            let deps = ArchiveManager.shared.checkDependencies(for: item.url.pathExtension)
            missingDeps.formUnion(deps)
        }
        
        if !missingDeps.isEmpty {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "archive.tool.missing".localized
                alert.informativeText = String(format: "archive.tool.install".localized, missingDeps.sorted().joined(separator: " "))
                alert.addButton(withTitle: "common.ok".localized)
                alert.runModal()
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingTitle = "progress.decompress".localized
            self.processingProgress = 0
            self.processingDetail = ""
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let total = Double(supported.count)
            var current = 0.0
            
            for item in supported {
                DispatchQueue.main.async {
                    self.processingDetail = item.name
                }
                
                let dir = destination ?? item.url.deletingLastPathComponent()
                let ext = item.url.pathExtension.lowercased()
                
                if ext == "zip" {
                    // Pass reportProgress: false to avoid jitter
                    self.decompressZip(item.url, to: dir, reportProgress: false)
                } else {
                    ArchiveManager.shared.extractAll(from: item.url, to: dir)
                }
                
                current += 1.0
                DispatchQueue.main.async {
                    self.processingProgress = current / total
                }
            }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processingProgress = nil
                self.processingDetail = ""
                self.processingTitle = ""
                self.loadFiles()
            }
        }
    }
    
    func decompress(_ item: FileItem, to destination: URL? = nil) {
        let deps = ArchiveManager.shared.checkDependencies(for: item.url.pathExtension)
        if !deps.isEmpty {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "archive.tool.missing".localized
                alert.informativeText = String(format: "archive.tool.install".localized, deps.joined(separator: " "))
                alert.addButton(withTitle: "common.ok".localized)
                alert.runModal()
            }
            return
        }
        
        // Use ArchiveManager's extractFolder for full extraction
        // This supports 7z, rar, etc.
        let dir = destination ?? item.url.deletingLastPathComponent()
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingTitle = "progress.decompress".localized
            self.processingProgress = nil // Indeterminate
            self.processingDetail = item.name
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Extract all contents
            // ArchiveManager.extractFolder with empty folder string usually means extract root
            // But our current implementation of extractFolder takes a specific folder inside archive.
            // We need a "extractAll" method in ArchiveManager or adapt extractFolder.
            // Let's modify ArchiveManager to support extracting root if folder is empty/root.
            
            // For now, let's assume we want to extract everything to 'dir'.
            // If it's a zip, we used ditto before.
            // For 7z/rar, we need ArchiveManager logic.
            
            // Let's implement a generic extractAll in ArchiveManager or here.
            // Since ArchiveManager encapsulates tools, it's better there.
            // But I can't edit ArchiveManager right now easily without context switch.
            // Wait, I can call extractFolder with "" or "/"?
            // In ArchiveManager:
            // zip: unzip archive.zip "*" -d dest
            // tar: tar -xf archive.tar -C dest
            // 7z: 7z x archive -o{dest}
            // unar: unar -o dest
            
            // Let's try calling extractFolder with empty string, assuming I'll fix ArchiveManager to handle it.
            // Or I can just check extension here.
            
            let ext = item.url.pathExtension.lowercased()
            if ext == "zip" {
                // Keep existing efficient ditto for zip if preferred, or switch to ArchiveManager
                // ditto is native and good for zip.
                self.decompressZip(item.url, to: dir)
            } else {
                // Use ArchiveManager for others (7z, rar, tar...)
                // We need to ensure ArchiveManager supports full extraction.
                // Let's call a new method I'll add to ArchiveManager via a separate edit, 
                // or misuse extractFolder if possible.
                // Actually, let's implement the logic here using ArchiveManager's helper if possible,
                // or just use the tool directly if I know the command.
                // Better: Update ArchiveManager to have extractAll.
                
                // Since I cannot update ArchiveManager in this turn (I am editing FileManagerCustom),
                // I will use ArchiveManager.extractFolder(folder: "", ...) and rely on it working or update it next.
                // Actually, looking at ArchiveManager code I just wrote:
                // 7z: 7z x archive -o{dest} folder
                // if folder is empty, it might be "7z x archive -o{dest} " -> 7z might complain or extract all.
                // unar: unar ... folder -> if folder empty, extracts all?
                
                // Safer: I will implement a temporary local execution or update ArchiveManager in next step.
                // But I should fix it now.
                // I will update ArchiveManager to handle empty folder string as "extract all".
                
                ArchiveManager.shared.extractAll(from: item.url, to: dir)
            }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processingProgress = nil
                self.processingDetail = ""
                self.processingTitle = ""
                self.loadFiles()
            }
        }
    }
    
    private func decompressZip(_ url: URL, to dir: URL, reportProgress: Bool = true) {
        let total = reportProgress ? countZipEntries(url) : 0
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-x", "-k", "-v", url.path, dir.path]
        p.environment = (ProcessInfo.processInfo.environment.merging(["LC_ALL": "C", "LANG": "C"], uniquingKeysWith: { _, new in new }))
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        
        let outFH = outPipe.fileHandleForReading
        let errFH = errPipe.fileHandleForReading
        var outBuffer = Data()
        var errBuffer = Data()
        
        processingProcess = p
        var processed = 0
        
        func handleLines(_ data: Data, buffer: inout Data) {
            guard !data.isEmpty else { return }
            buffer.append(data)
            guard let s = String(data: buffer, encoding: .utf8) else { return }
            let lines = s.split(whereSeparator: \.isNewline).map { String($0) }
            if lines.count > 1 {
                buffer = Data(lines.last!.utf8)
                for i in 0..<(lines.count - 1) {
                    let line = lines[i]
                    if !line.isEmpty {
                        processed += 1
                        if total > 0 {
                            let pr = min(1.0, Double(processed) / Double(total))
                            DispatchQueue.main.async {
                                self.processingProgress = pr
                                self.processingDetail = line
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.processingDetail = line
                            }
                        }
                    }
                }
            }
        }
        
        outFH.readabilityHandler = { handle in handleLines(handle.availableData, buffer: &outBuffer) }
        errFH.readabilityHandler = { handle in handleLines(handle.availableData, buffer: &errBuffer) }
        
        try? p.run()
        p.waitUntilExit()
        
        outFH.readabilityHandler = nil
        errFH.readabilityHandler = nil
        processingProcess = nil
    }
    
    func decompressTo(_ item: FileItem) {
        let panel = NSOpenPanel()
        panel.title = "menu.decompressTo".localized
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.decompress(item, to: url)
            }
        }
    }
    
    func decompressTo(_ items: [FileItem]) {
        let panel = NSOpenPanel()
        panel.title = "menu.decompressTo".localized
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.decompress(items, to: url)
            }
        }
    }
    
    func cancelProcessing() {
        processingProcess?.terminate()
        processingProcess = nil
        progressTimer?.cancel()
        progressTimer = nil
        isProcessing = false
        processingProgress = nil
        processingDetail = ""
        processingTitle = ""
    }
    
    func rename(_ item: FileItem) {
        let oldURL = item.url
        let oldName = oldURL.lastPathComponent
        let alert = NSAlert()
        alert.messageText = "menu.rename".localized
        alert.informativeText = "file.rename.prompt".localized
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        tf.stringValue = oldName
        alert.accessoryView = tf
        alert.addButton(withTitle: "common.ok".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        let response = alert.runModal()
        if response != .alertFirstButtonReturn { return }
        var newName = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        if !item.isDirectory {
            let ext = oldURL.pathExtension
            if !ext.isEmpty {
                let suf = "." + ext
                if !newName.lowercased().hasSuffix(suf.lowercased()) {
                    newName += suf
                }
            }
        }
        let dest = oldURL.deletingLastPathComponent().appendingPathComponent(newName)
        if fileManager.fileExists(atPath: dest.path) {
            let fail = NSAlert()
            fail.messageText = "file.rename.failed".localized
            fail.informativeText = "file.rename.exists".localized
            fail.runModal()
            return
        }
        do {
            try fileManager.moveItem(at: oldURL, to: dest)
            loadFiles()
        } catch {
            let fail = NSAlert()
            fail.messageText = "file.rename.failed".localized
            fail.informativeText = error.localizedDescription
            fail.runModal()
        }
    }
    
    func createFolder(baseName: String = "file.newFolder".localized) {
        let dest = uniqueURL(in: currentPath, baseName: baseName, ext: nil)
        do {
            try fileManager.createDirectory(at: dest, withIntermediateDirectories: false, attributes: nil)
            loadFiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createEmptyFile(baseName: String = "file.newFile".localized, ext: String = "txt") {
        let dest = uniqueURL(in: currentPath, baseName: baseName, ext: ext)
        let ok = fileManager.createFile(atPath: dest.path, contents: Data(), attributes: nil)
        if ok {
            loadFiles()
        } else {
            errorMessage = "file.create.failed".localized
        }
    }
    
    func prepareItemsForDrag(_ items: [FileItem]) -> [URL] {
        if !isInsideArchive || currentArchiveURL == nil {
            return items.compactMap { $0.isVirtual ? nil : $0.url }
        }
        
        guard let archiveURL = currentArchiveURL else { return [] }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        var resultURLs: [URL] = []
        
        for item in items {
            // Reconstruct entry path
            let archivePath = archiveURL.path
            let itemPath = item.url.path
            if itemPath.hasPrefix(archivePath) {
                var entryPath = String(itemPath.dropFirst(archivePath.count))
                if entryPath.hasPrefix("/") { entryPath.removeFirst() }
                
                if item.isDirectory {
                    // Extract folder structure
                    ArchiveManager.shared.extractFolder(folder: entryPath, from: archiveURL, to: tempDir)
                    // The extracted path will be tempDir + entryPath
                    resultURLs.append(tempDir.appendingPathComponent(entryPath))
                } else {
                    let dest = tempDir.appendingPathComponent(item.name)
                    ArchiveManager.shared.extract(file: entryPath, from: archiveURL, to: dest)
                    resultURLs.append(dest)
                }
            }
        }
        
        return resultURLs
    }
    
    func handleDroppedProviders(_ providers: [NSItemProvider]) {
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let nsurl = item as? NSURL {
                        self.handleDroppedURL(nsurl as URL)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        self.handleDroppedURL(url)
                    }
                }
            }
        }
    }
    
    func prepareItemForPreview(_ item: FileItem, completion: @escaping (URL?) -> Void) {
        if !item.isVirtual {
            completion(item.url)
            return
        }
        
        guard let archiveURL = currentArchiveURL else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Preview_" + UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            let archivePath = archiveURL.path
            let itemPath = item.url.path
            if itemPath.hasPrefix(archivePath) {
                var entryPath = String(itemPath.dropFirst(archivePath.count))
                if entryPath.hasPrefix("/") { entryPath.removeFirst() }
                
                let dest = tempDir.appendingPathComponent(item.name)
                ArchiveManager.shared.extract(file: entryPath, from: archiveURL, to: dest)
                
                DispatchQueue.main.async {
                    completion(dest)
                }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    private func handleDroppedURL(_ src: URL) {
        // Add to archive if inside one
        if isInsideArchive, let archiveURL = currentArchiveURL {
            ArchiveManager.shared.add([src], to: archiveURL)
            loadFiles()
            return
        }
        
        let destDir = currentPath
        if src.deletingLastPathComponent() == destDir {
            return
        }
        let name = src.lastPathComponent
        var dest = destDir.appendingPathComponent(name)
        if fileManager.fileExists(atPath: dest.path) {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "file.exists".localized
                alert.informativeText = "file.chooseOperation".localized
                alert.addButton(withTitle: "file.replace".localized)
                alert.addButton(withTitle: "file.keepBoth".localized)
                alert.addButton(withTitle: "common.cancel".localized)
                let resp = alert.runModal()
                if resp == .alertFirstButtonReturn {
                    do {
                        try self.fileManager.removeItem(at: dest)
                        try self.fileManager.moveItem(at: src, to: dest)
                        self.loadFiles()
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                } else if resp == .alertSecondButtonReturn {
                    let base = src.deletingPathExtension().lastPathComponent
                    let ext = src.pathExtension.isEmpty ? nil : src.pathExtension
                    let unique = self.uniqueURL(in: destDir, baseName: base, ext: ext)
                    do {
                        try self.fileManager.moveItem(at: src, to: unique)
                        self.loadFiles()
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            do {
                try fileManager.moveItem(at: src, to: dest)
                DispatchQueue.main.async { self.loadFiles() }
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            }
        }
    }
    
    private func uniqueURL(in directory: URL, baseName: String, ext: String?) -> URL {
        var index = 1
        func makeName(_ i: Int) -> String {
            if let ext = ext, !ext.isEmpty {
                if i == 1 { return "\(baseName) \("file.copy.suffix".localized).\(ext)" }
                return "\(baseName) \("file.copy.suffix".localized) \(i).\(ext)"
            } else {
                if i == 1 { return "\(baseName) \("file.copy.suffix".localized)" }
                return "\(baseName) \("file.copy.suffix".localized) \(i)"
            }
        }
        var candidate = directory.appendingPathComponent(makeName(index))
        while fileManager.fileExists(atPath: candidate.path) {
            index += 1
            candidate = directory.appendingPathComponent(makeName(index))
        }
        return candidate
    }
    
    private func countZipEntries(_ url: URL) -> Int {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-l", url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        var text = ""
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            text = String(data: data, encoding: .utf8) ?? ""
        } catch {
            return 0
        }
        p.waitUntilExit()
        var count = 0
        let lines = text.split(whereSeparator: \.isNewline).map { String($0) }
        for line in lines.reversed() {
            if let r = line.range(of: #"([0-9]+)\s+files"#, options: .regularExpression) {
                let s = String(line[r])
                let digits = s.split(whereSeparator: { !"0123456789".contains($0) }).first.flatMap { Int($0) }
                if let n = digits { count = n }
                break
            }
        }
        return count
    }
    
    func requestAccess(for url: URL) {
        PermissionManager.shared.requestAccess(for: url) { [weak self] granted in
            if granted {
                self?.loadFiles()
            }
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.navigateTo(url)
            }
        }
    }
    
    var canGoBack: Bool {
        historyIndex > 0
    }
    
    var canGoForward: Bool {
        historyIndex < pathHistory.count - 1
    }
    
    var canGoUp: Bool {
        currentPath != currentPath.deletingLastPathComponent()
    }
}
