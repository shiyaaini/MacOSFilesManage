import Foundation
import AppKit

struct FileItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let icon: NSImage
    let depth: Int
    let isVirtual: Bool
    
    init(url: URL, depth: Int = 0) {
        self.id = url.isFileURL ? url.path : url.absoluteString
        self.url = url
        self.name = url.lastPathComponent
        self.isVirtual = false
        
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
        
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.size = attributes?[.size] as? Int64 ?? 0
        self.modificationDate = attributes?[.modificationDate] as? Date
        
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self.depth = 0
    }
    
    init(linkURL: URL, title: String, icon: NSImage?) {
        self.id = linkURL.absoluteString
        self.url = linkURL
        self.name = title
        self.isDirectory = false
        self.size = 0
        self.modificationDate = nil
        self.isVirtual = true
        if let icon = icon {
            self.icon = icon
        } else {
            self.icon = NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage(size: NSSize(width: 16, height: 16))
        }
        self.depth = 0
    }
    
    init(archiveEntry: ArchiveEntry, archiveURL: URL, depth: Int = 0) {
        // Construct a virtual URL: archive path + entry path
        // e.g. /path/to/archive.zip/folder/file.txt
        // This URL does not exist on disk, but represents the entry location.
        let fullPath = archiveURL.path + "/" + archiveEntry.path
        self.url = URL(fileURLWithPath: fullPath)
        self.id = self.url.path
        self.name = archiveEntry.name
        self.isDirectory = archiveEntry.isDirectory
        self.size = archiveEntry.size
        self.modificationDate = archiveEntry.modifiedDate
        self.depth = depth
        self.isVirtual = true
        
        if archiveEntry.isDirectory {
            self.icon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
        } else {
            self.icon = NSWorkspace.shared.icon(forFileType: self.url.pathExtension)
        }
    }
    
    var formattedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension URL {
    var pathExtensionLowercased: String { pathExtension.lowercased() }
    var isImageFile: Bool { ["png","jpg","jpeg","gif","heic","tiff","bmp","webp"].contains(pathExtensionLowercased) }
    var isPDFFile: Bool { pathExtensionLowercased == "pdf" }
    var isTextFile: Bool { ["txt","md","json","xml","yaml","yml","csv","log"].contains(pathExtensionLowercased) }
}
