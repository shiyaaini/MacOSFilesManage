
import Foundation

struct ArchiveEntry: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date?
    
    var name: String {
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

class ArchiveManager {
    static let shared = ArchiveManager()
    
    private init() {}
    
    private let fm = FileManager.default
    
    func checkDependencies(for ext: String) -> [String] {
        let e = ext.lowercased()
        if ["7z"].contains(e) {
            if !checkCommand("7z") && !checkCommand("7zz") && !checkCommand("lsar") { return ["p7zip", "sevenzip"] }
        }
        if ["rar"].contains(e) {
            // Check for unar (lsar), unrar, or rar
            if !checkCommand("lsar") && !checkCommand("unrar") && !checkCommand("rar") { return ["unar"] }
        }
        return []
    }
    
    private func checkCommand(_ cmd: String) -> Bool {
        let paths = ["/usr/bin", "/usr/local/bin", "/opt/homebrew/bin", "/bin", "/sbin"]
        for p in paths {
            let url = URL(fileURLWithPath: p).appendingPathComponent(cmd)
            if fm.isExecutableFile(atPath: url.path) { return true }
        }
        return false
    }
    
    func isSupportedArchive(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["zip", "tar", "gz", "tgz", "bz2", "tbz", "7z", "rar"].contains(ext)
    }
    
    func listContents(of url: URL) -> [ArchiveEntry] {
        let ext = url.pathExtension.lowercased()
        if ext == "zip" {
            return listZipContents(url)
        } else if ["tar", "gz", "tgz", "bz2", "tbz"].contains(ext) {
            return listTarContents(url)
        } else if ["7z", "rar"].contains(ext) {
            // Try lsar first (part of unar) as it supports both and has nice JSON output
            if checkCommand("lsar") {
                return listLsarContents(url)
            }
            // Fallback for 7z/7zz
            if ext == "7z" {
                if checkCommand("7z") { return list7zContents(url, cmd: "7z") }
                if checkCommand("7zz") { return list7zContents(url, cmd: "7zz") }
            }
            // Fallback for rar
            if ext == "rar" {
                if checkCommand("unrar") { return listUnrarContents(url) }
                if checkCommand("rar") { return listRarContents(url) }
            }
        }
        return []
    }
    
    // MARK: - Listing Implementations
    
    private func listLsarContents(_ url: URL) -> [ArchiveEntry] {
        let p = Process()
        p.executableURL = resolveCommand("lsar")
        p.arguments = ["-j", url.path] // JSON output
        
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        struct LsarOutput: Codable {
            let lsarContents: [LsarEntry]?
        }
        struct LsarEntry: Codable {
            let XADFileName: String
            let XADFileSize: Int64?
            let XADIsDirectory: Bool?
            let XADLastModificationDate: String?
        }
        
        guard let output = try? JSONDecoder().decode(LsarOutput.self, from: data),
              let contents = output.lsarContents else { return [] }
        
        var entries: [ArchiveEntry] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z" // Example format from lsar
        
        for item in contents {
            let path = item.XADFileName
            let isDir = item.XADIsDirectory ?? false
            let size = item.XADFileSize ?? 0
            // Date parsing might need adjustment based on actual output
            let date = item.XADLastModificationDate.flatMap { dateFormatter.date(from: $0) }
            
            entries.append(ArchiveEntry(path: path, isDirectory: isDir, size: size, modifiedDate: date))
        }
        return entries
    }
    
    private func list7zContents(_ url: URL, cmd: String) -> [ArchiveEntry] {
        let p = Process()
        p.executableURL = resolveCommand(cmd)
        // 7z l -slt archive
        // -slt: show technical information for l (List) command
        p.arguments = ["l", "-slt", url.path]
        
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        
        var entries: [ArchiveEntry] = []
        let blocks = output.components(separatedBy: "\n\n")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for block in blocks {
            let lines = block.components(separatedBy: .newlines)
            var path: String?
            var size: Int64 = 0
            var isDir = false
            var modified: Date?
            
            for line in lines {
                if line.hasPrefix("Path = ") {
                    path = String(line.dropFirst(7))
                } else if line.hasPrefix("Size = ") {
                    size = Int64(String(line.dropFirst(7))) ?? 0
                } else if line.hasPrefix("Attributes = ") {
                    // Attributes can be "D" (directory) or "A" (archive) or "....D"
                    // 7z -slt attributes usually look like "D...." or "....D" depending on version?
                    // Actually usually just "D" in attributes string means directory.
                    isDir = line.contains("D")
                } else if line.hasPrefix("Modified = ") {
                    let dateStr = String(line.dropFirst(11))
                    // 7z date format is usually YYYY-MM-DD HH:MM:SS
                    modified = dateFormatter.date(from: String(dateStr.prefix(19)))
                }
            }
            
            if let p = path, !p.isEmpty, p != url.path { 
                 entries.append(ArchiveEntry(path: p, isDirectory: isDir, size: size, modifiedDate: modified))
            }
        }
        
        return entries
    }
    
    private func listUnrarContents(_ url: URL) -> [ArchiveEntry] {
        // Implement unrar l parsing
        return [] // Placeholder
    }
    
    private func listRarContents(_ url: URL) -> [ArchiveEntry] {
        return [] // Placeholder
    }
    
    private func listZipContents(_ url: URL) -> [ArchiveEntry] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
        // -l: list long format (Unix-like)
        // -T: print date in sortable decimal format (yyyymmdd.hhmmss) - wait, macOS zipinfo might not support -T properly or output differs.
        // Let's stick to default zipinfo or unzip -l.
        // unzip -l only gives size, date, time, name. No directory indicator explicitly (except trailing slash).
        // zipinfo gives permissions which helps identify directories.
        p.arguments = ["-1", url.path] // -1: filenames only. simple parsing.
        
        // Actually, to build a proper tree, we need isDirectory.
        // `zipinfo` default output:
        // -rw-r--r--  3.0 unx     2368 tx defX 21-Feb-26 12:34 filename.txt
        // drwxr-xr-x  3.0 unx        0 bx stor 21-Feb-26 12:34 folder/
        
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-Z", "-s", url.path] // -s: short Unix "ls -l" format
        
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        
        var entries: [ArchiveEntry] = []
        let lines = output.components(separatedBy: .newlines)
        
        // Output example:
        // Archive:  /path/to/file.zip
        // Zip file size: 1234 bytes, number of entries: 5
        // -rw-r--r--  3.0 unx     2368 tx defX 21-Feb-26 12:34 filename.txt
        // drwxr-xr-x  3.0 unx        0 bx stor 21-Feb-26 12:34 folder/
        
        for line in lines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            // Basic heuristic parsing
            // Permissions are 1st (10 chars).
            // Name is last.
            if parts.count >= 7, let perms = parts.first, perms.count == 10 {
                let isDir = perms.hasPrefix("d")
                let sizeIndex = parts.count > 3 ? 3 : 0 // roughly
                let size = Int64(parts[sizeIndex]) ?? 0
                
                // Name starts after date/time.
                // Format: perms ver os size method date time name
                // -rw-r--r--  3.0 unx 2368 tx defX 21-Feb-26 12:34 filename.txt
                // Indices: 0(perms) 1(ver) 2(os) 3(size) 4(Tx) 5(method) 6(Date) 7(Time) 8+(Name)
                
                if parts.count >= 9 {
                    let nameParts = parts.suffix(from: 8)
                    let name = nameParts.joined(separator: " ")
                    entries.append(ArchiveEntry(path: name, isDirectory: isDir, size: size, modifiedDate: nil))
                }
            }
        }
        return entries
    }
    
    private func listTarContents(_ url: URL) -> [ArchiveEntry] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-tvf", url.path]
        
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        
        var entries: [ArchiveEntry] = []
        let lines = output.components(separatedBy: .newlines)
        
        // Output example:
        // drwxr-xr-x  0 user group       0 Feb 26 12:34 folder/
        // -rw-r--r--  0 user group    1234 Feb 26 12:34 file.txt
        
        for line in lines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 8, let perms = parts.first {
                let isDir = perms.hasPrefix("d")
                // Index 4 is size usually
                // perms links owner group size date time name
                // drwxr-xr-x 0 user group 0 Feb 26 12:34 folder/
                // Indices: 0 1 2 3 4 5 6 7 8+
                
                if let s = Int64(parts[4]) {
                    let nameParts = parts.suffix(from: 8)
                    let name = nameParts.joined(separator: " ")
                    entries.append(ArchiveEntry(path: name, isDirectory: isDir, size: s, modifiedDate: nil))
                }
            }
        }
        return entries
    }
    
    private func resolveCommand(_ cmd: String) -> URL {
        let paths = ["/usr/bin", "/usr/local/bin", "/opt/homebrew/bin", "/bin", "/sbin"]
        for p in paths {
            let url = URL(fileURLWithPath: p).appendingPathComponent(cmd)
            if fm.isExecutableFile(atPath: url.path) { return url }
        }
        return URL(fileURLWithPath: "/usr/bin/" + cmd) // Fallback
    }
    
    func extract(file: String, from archive: URL, to dest: URL) {
        let ext = archive.pathExtension.lowercased()
        let p = Process()
        
        if ext == "zip" {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            p.arguments = ["-p", archive.path, file] // -p pipe to stdout
            
            let pipe = Pipe()
            p.standardOutput = pipe
            try? p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            try? data.write(to: dest)
            return
        }
        
        if ["tar", "gz", "tgz", "bz2", "tbz"].contains(ext) {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            p.arguments = ["-xf", archive.path, "-O", file] // -O pipe to stdout
            
            let pipe = Pipe()
            p.standardOutput = pipe
            try? p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            try? data.write(to: dest)
            return
        }
        
        // 7z using 7z/7zz command (preferred for 7z files if available)
        if ext == "7z" {
            let cmd = checkCommand("7zz") ? "7zz" : (checkCommand("7z") ? "7z" : nil)
            if let cmd = cmd {
                p.executableURL = resolveCommand(cmd)
                // 7z e archive -o{dir} file -so
                // -so writes to stdout
                // For 7z, -so works.
                p.arguments = ["e", archive.path, "-so", file]
                
                let pipe = Pipe()
                p.standardOutput = pipe
                try? p.run()
                p.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                try? data.write(to: dest)
                return
            }
        }
        
        // 7z / rar using unar (fallback)
        if checkCommand("unar") {
            // unar doesn't support pipe to stdout easily.
            // We must extract to a temp directory and then move/read.
            // But 'dest' is the target file URL.
            // So we extract 'file' to 'dest.deletingLastPathComponent()' ??
            // unar usage: unar -o output_dir archive file_to_extract
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            p.executableURL = resolveCommand("unar")
            // -o tempDir
            // -D no top-level directory (important!)
            // -f force
            p.arguments = ["-o", tempDir.path, "-D", "-f", archive.path, file]
            
            try? p.run()
            p.waitUntilExit()
            
            // Find the extracted file in tempDir
            // It should be at tempDir/file
            let extracted = tempDir.appendingPathComponent(file)
            if fm.fileExists(atPath: extracted.path) {
                // Move to dest
                try? fm.moveItem(at: extracted, to: dest)
            }
            try? fm.removeItem(at: tempDir)
            return
        }
        
        // Fallback for rar using unrar/rar
        if ext == "rar" {
            if checkCommand("unrar") {
                p.executableURL = resolveCommand("unrar")
                // unrar p -inul archive file
                // p: print to stdout
                // -inul: disable messages
                p.arguments = ["p", "-inul", archive.path, file]
                
                let pipe = Pipe()
                p.standardOutput = pipe
                try? p.run()
                p.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                try? data.write(to: dest)
                return
            }
        }
    }
    
    func extractAll(from archive: URL, to dest: URL) {
        let ext = archive.pathExtension.lowercased()
        let p = Process()
        
        if ext == "zip" {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            p.arguments = [archive.path, "-d", dest.path]
            try? p.run()
            p.waitUntilExit()
            return
        }
        
        if ["tar", "gz", "tgz", "bz2", "tbz"].contains(ext) {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            p.arguments = ["-xf", archive.path, "-C", dest.path]
            try? p.run()
            p.waitUntilExit()
            return
        }
        
        // 7z using 7z/7zz command (preferred for 7z files)
        if ext == "7z" {
            let cmd = checkCommand("7zz") ? "7zz" : (checkCommand("7z") ? "7z" : nil)
            if let cmd = cmd {
                p.executableURL = resolveCommand(cmd)
                // 7z x archive -o{dest}
                p.arguments = ["x", archive.path, "-o\(dest.path)"]
                try? p.run()
                p.waitUntilExit()
                return
            }
        }
        
        // Use unar for everything else if available (fallback)
        if checkCommand("unar") {
            p.executableURL = resolveCommand("unar")
            // unar -o dest -D archive
            p.arguments = ["-o", dest.path, "-D", "-f", archive.path]
            try? p.run()
            p.waitUntilExit()
            return
        }
    }
    
    func extractFolder(folder: String, from archive: URL, to dest: URL) {
        let ext = archive.pathExtension.lowercased()
        let p = Process()
        
        if ext == "zip" {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            p.arguments = [archive.path, "\(folder)*", "-d", dest.path]
            try? p.run()
            p.waitUntilExit()
            return
        }
        
        if ["tar", "gz", "tgz", "bz2", "tbz"].contains(ext) {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            p.arguments = ["-xf", archive.path, "-C", dest.path, folder]
            try? p.run()
            p.waitUntilExit()
            return
        }
        
        // 7z using 7z/7zz command (preferred for 7z files)
        if ext == "7z" {
            let cmd = checkCommand("7zz") ? "7zz" : (checkCommand("7z") ? "7z" : nil)
            if let cmd = cmd {
                p.executableURL = resolveCommand(cmd)
                // 7z x archive -o{dest} folder
                p.arguments = ["x", archive.path, "-o\(dest.path)", folder]
                try? p.run()
                p.waitUntilExit()
                return
            }
        }
        
        // Use unar for everything else if available (fallback)
        if checkCommand("unar") {
            p.executableURL = resolveCommand("unar")
            // unar -o dest -D archive folder
            p.arguments = ["-o", dest.path, "-D", "-f", archive.path, folder]
            try? p.run()
            p.waitUntilExit()
            return
        }
    }
    
    func add(_ files: [URL], to archive: URL) {
        guard archive.pathExtension.lowercased() == "zip" else { return }
        
        for file in files {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            p.currentDirectoryURL = file.deletingLastPathComponent()
            // -u update, -r recurse (for folders)
            p.arguments = ["-u", "-r", archive.path, file.lastPathComponent]
            try? p.run()
            p.waitUntilExit()
        }
    }
    
    func delete(_ entryPath: String, from archive: URL) {
        guard archive.pathExtension.lowercased() == "zip" else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-d", archive.path, entryPath]
        try? p.run()
        p.waitUntilExit()
    }
}
