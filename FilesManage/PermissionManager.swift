import Foundation
import AppKit

class PermissionManager {
    static let shared = PermissionManager()
    
    private var accessibleURLs: Set<URL> = []
    private var bookmarkedURLs: [String: Data] = [:]
    private let bookmarksKey = "securityBookmarks"
    
    private init() {
        loadBookmarks()
    }
    
    // 检查是否可以访问某个 URL
    func canAccess(_ url: URL) -> Bool {
        // 检查是否在已授权列表中
        if accessibleURLs.contains(url) {
            return true
        }
        
        // 检查父目录是否已授权
        var current = url
        while current.path != "/" {
            if accessibleURLs.contains(current) {
                return true
            }
            current = current.deletingLastPathComponent()
        }
        
        // 尝试直接访问
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    
    // 请求访问权限
    func requestAccess(for url: URL, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.message = "file.permission.message".localized
            panel.prompt = "file.permission.grant".localized
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            
            // 尝试定位到目标文件夹
            panel.directoryURL = url.deletingLastPathComponent()
            
            panel.begin { [weak self] response in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                if response == .OK, let selectedURL = panel.url {
                    // 保存 security-scoped bookmark
                    self.saveBookmark(for: selectedURL)
                    self.accessibleURLs.insert(selectedURL)
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    // 开始访问 security-scoped 资源
    func startAccessing(_ url: URL) -> Bool {
        // 先检查是否有 bookmark
        if let bookmarkData = bookmarkedURLs[url.path] {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    // Bookmark 过期，重新保存
                    saveBookmark(for: url)
                }
                
                let success = resolvedURL.startAccessingSecurityScopedResource()
                if success {
                    accessibleURLs.insert(resolvedURL)
                }
                return success
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
        
        // 检查父目录的 bookmark
        var current = url.deletingLastPathComponent()
        while current.path != "/" {
            if let bookmarkData = bookmarkedURLs[current.path] {
                do {
                    var isStale = false
                    let resolvedURL = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    
                    let success = resolvedURL.startAccessingSecurityScopedResource()
                    if success {
                        accessibleURLs.insert(resolvedURL)
                        return true
                    }
                } catch {
                    print("Failed to resolve parent bookmark: \(error)")
                }
            }
            current = current.deletingLastPathComponent()
        }
        
        return false
    }
    
    // 停止访问
    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
    
    // 保存 bookmark
    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            bookmarkedURLs[url.path] = bookmarkData
            saveBookmarksToDefaults()
        } catch {
            print("Failed to create bookmark: \(error)")
        }
    }
    
    // 保存到 UserDefaults
    private func saveBookmarksToDefaults() {
        UserDefaults.standard.set(bookmarkedURLs, forKey: bookmarksKey)
    }
    
    // 从 UserDefaults 加载
    private func loadBookmarks() {
        if let saved = UserDefaults.standard.dictionary(forKey: bookmarksKey) as? [String: Data] {
            bookmarkedURLs = saved
            
            // 恢复所有已授权的 URL
            for (path, bookmarkData) in bookmarkedURLs {
                do {
                    var isStale = false
                    let url = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    
                    if isStale {
                        // 过期的 bookmark，尝试重新保存
                        saveBookmark(for: url)
                    }
                    
                    accessibleURLs.insert(url)
                } catch {
                    print("Failed to load bookmark for \(path): \(error)")
                }
            }
        }
    }
    
    // 清除所有权限
    func clearAllPermissions() {
        bookmarkedURLs.removeAll()
        accessibleURLs.removeAll()
        UserDefaults.standard.removeObject(forKey: bookmarksKey)
    }
}

