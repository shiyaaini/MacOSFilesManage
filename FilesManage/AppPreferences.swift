import Foundation
import AppKit

final class AppPreferences {
    static let shared = AppPreferences()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let language = "app.language"
        static let theme = "app.theme"
        static let enableBlur = "app.enableBlur"
        static let terminalOpacity = "app.terminalOpacity"
        static let rememberWindowState = "app.rememberWindowState"
        static let autoRefreshUI = "app.autoRefreshUI"
        static let enablePreview = "app.enablePreview"
        static let previewPaneWidth = "app.previewPaneWidth"
        static let folderViewModeMap = "app.folderViewModeMap"
        static let folderGridSizeMap = "app.folderGridSizeMap"
        static let appTagList = "app.tag.list"
        static let appTagsMap = "app.tags.map"
        static let tagURLsMap = "app.tag.urls.map"
        static let tagLinksMap = "app.tag.links.map"
    }
    
    struct TagLink: Codable, Equatable, Hashable {
        var url: String
        var title: String
        var iconPNGData: Data?
        
        var nsImage: NSImage? {
            guard let d = iconPNGData else { return nil }
            return NSImage(data: d)
        }
    }
    
    var language: String {
        get { defaults.string(forKey: Keys.language) ?? "system" }
        set { defaults.set(newValue, forKey: Keys.language) }
    }
    
    var theme: String {
        get { defaults.string(forKey: Keys.theme) ?? "system" }
        set { defaults.set(newValue, forKey: Keys.theme) }
    }
    
    var enableBlur: Bool {
        get { defaults.bool(forKey: Keys.enableBlur) }
        set { defaults.set(newValue, forKey: Keys.enableBlur) }
    }
    
    var terminalOpacity: Double {
        get {
            let value = defaults.double(forKey: Keys.terminalOpacity)
            return value == 0 ? 0.95 : value
        }
        set { defaults.set(newValue, forKey: Keys.terminalOpacity) }
    }
    
    var rememberWindowState: Bool {
        get { defaults.bool(forKey: Keys.rememberWindowState) }
        set { defaults.set(newValue, forKey: Keys.rememberWindowState) }
    }
    
    var autoRefreshUI: Bool {
        get { defaults.bool(forKey: Keys.autoRefreshUI) }
        set { defaults.set(newValue, forKey: Keys.autoRefreshUI) }
    }
    
    var enablePreview: Bool {
        get { true }
        set { defaults.set(true, forKey: Keys.enablePreview) }
    }
    
    var previewPaneWidth: Double {
        get {
            let v = defaults.double(forKey: Keys.previewPaneWidth)
            return v == 0 ? 320.0 : v
        }
        set { defaults.set(newValue, forKey: Keys.previewPaneWidth) }
    }
    
    func folderViewMode(for path: String) -> String {
        let dict = defaults.dictionary(forKey: Keys.folderViewModeMap) as? [String: String] ?? [:]
        return dict[path] ?? "list"
    }
    
    func setFolderViewMode(_ mode: String, for path: String) {
        var dict = defaults.dictionary(forKey: Keys.folderViewModeMap) as? [String: String] ?? [:]
        dict[path] = mode
        defaults.set(dict, forKey: Keys.folderViewModeMap)
    }
    
    func folderGridSize(for path: String) -> Double {
        let dict = defaults.dictionary(forKey: Keys.folderGridSizeMap) as? [String: Double] ?? [:]
        return dict[path] ?? 96.0
    }
    
    func setFolderGridSize(_ size: Double, for path: String) {
        var dict = defaults.dictionary(forKey: Keys.folderGridSizeMap) as? [String: Double] ?? [:]
        dict[path] = size
        defaults.set(dict, forKey: Keys.folderGridSizeMap)
    }
    
    var tagList: [String] {
        get { defaults.stringArray(forKey: Keys.appTagList) ?? [] }
        set { defaults.set(newValue, forKey: Keys.appTagList) }
    }
    
    func addTag(_ name: String) {
        var list = tagList
        if !list.contains(name) {
            list.append(name)
            tagList = list
            NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
        }
    }
    
    func removeTag(_ name: String) {
        var list = tagList.filter { $0 != name }
        tagList = list
        var dict = defaults.dictionary(forKey: Keys.appTagsMap) as? [String: [String]] ?? [:]
        for (k, v) in dict {
            dict[k] = v.filter { $0 != name }
        }
        defaults.set(dict, forKey: Keys.appTagsMap)
        var urlMap = defaults.dictionary(forKey: Keys.tagURLsMap) as? [String: [String]] ?? [:]
        urlMap.removeValue(forKey: name)
        defaults.set(urlMap, forKey: Keys.tagURLsMap)
        NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
    }
    
    func tags(for appPath: String) -> [String] {
        let dict = defaults.dictionary(forKey: Keys.appTagsMap) as? [String: [String]] ?? [:]
        return dict[appPath] ?? []
    }
    
    func addApp(_ appPath: String, toTag tag: String) {
        var dict = defaults.dictionary(forKey: Keys.appTagsMap) as? [String: [String]] ?? [:]
        var arr = dict[appPath] ?? []
        if !arr.contains(tag) {
            arr.append(tag)
            dict[appPath] = arr
            defaults.set(dict, forKey: Keys.appTagsMap)
            NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
        }
    }
    
    func removeApp(_ appPath: String, fromTag tag: String) {
        var dict = defaults.dictionary(forKey: Keys.appTagsMap) as? [String: [String]] ?? [:]
        var arr = dict[appPath] ?? []
        arr.removeAll { $0 == tag }
        if arr.isEmpty {
            dict.removeValue(forKey: appPath)
        } else {
            dict[appPath] = arr
        }
        defaults.set(dict, forKey: Keys.appTagsMap)
        NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
    }
    
    func clearTags(for appPath: String) {
        var dict = defaults.dictionary(forKey: Keys.appTagsMap) as? [String: [String]] ?? [:]
        dict.removeValue(forKey: appPath)
        defaults.set(dict, forKey: Keys.appTagsMap)
        NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
    }
    
    func urls(for tag: String) -> [String] {
        let dict = defaults.dictionary(forKey: Keys.tagURLsMap) as? [String: [String]] ?? [:]
        return dict[tag] ?? []
    }
    
    func addURL(_ url: String, toTag tag: String) {
        var dict = defaults.dictionary(forKey: Keys.tagURLsMap) as? [String: [String]] ?? [:]
        var arr = dict[tag] ?? []
        if !arr.contains(url) {
            arr.append(url)
            dict[tag] = arr
            defaults.set(dict, forKey: Keys.tagURLsMap)
            NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
        }
    }
    
    func removeURL(_ url: String, fromTag tag: String) {
        var dict = defaults.dictionary(forKey: Keys.tagURLsMap) as? [String: [String]] ?? [:]
        var arr = dict[tag] ?? []
        arr.removeAll { $0 == url }
        if arr.isEmpty {
            dict.removeValue(forKey: tag)
        } else {
            dict[tag] = arr
        }
        defaults.set(dict, forKey: Keys.tagURLsMap)
        NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
    }
    
    func clearURLs(for tag: String) {
        var dict = defaults.dictionary(forKey: Keys.tagURLsMap) as? [String: [String]] ?? [:]
        dict.removeValue(forKey: tag)
        defaults.set(dict, forKey: Keys.tagURLsMap)
        NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
    }
    
    func links(for tag: String) -> [TagLink] {
        if let dict = defaults.dictionary(forKey: Keys.tagLinksMap) as? [String: Data],
           let data = dict[tag],
           let arr = try? JSONDecoder().decode([TagLink].self, from: data) {
            return arr
        }
        let legacy = defaults.dictionary(forKey: Keys.tagURLsMap) as? [String: [String]] ?? [:]
        let urls = legacy[tag] ?? []
        let migrated = urls.map { TagLink(url: $0, title: $0, iconPNGData: nil) }
        if !migrated.isEmpty {
            addLinks(migrated, toTag: tag)
        }
        return migrated
    }
    
    func addLink(_ link: TagLink, toTag tag: String) {
        var dict = defaults.dictionary(forKey: Keys.tagLinksMap) as? [String: Data] ?? [:]
        var arr = (try? JSONDecoder().decode([TagLink].self, from: dict[tag] ?? Data())) ?? []
        if !arr.contains(where: { $0.url == link.url }) {
            arr.append(link)
            if let data = try? JSONEncoder().encode(arr) {
                dict[tag] = data
                defaults.set(dict, forKey: Keys.tagLinksMap)
                NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
            }
        }
    }
    
    func addLinks(_ links: [TagLink], toTag tag: String) {
        var dict = defaults.dictionary(forKey: Keys.tagLinksMap) as? [String: Data] ?? [:]
        var arr = (try? JSONDecoder().decode([TagLink].self, from: dict[tag] ?? Data())) ?? []
        for l in links where !arr.contains(where: { $0.url == l.url }) {
            arr.append(l)
        }
        if let data = try? JSONEncoder().encode(arr) {
            dict[tag] = data
            defaults.set(dict, forKey: Keys.tagLinksMap)
            NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
        }
    }
    
    func removeLink(byURL url: String, fromTag tag: String) {
        var dict = defaults.dictionary(forKey: Keys.tagLinksMap) as? [String: Data] ?? [:]
        var arr = (try? JSONDecoder().decode([TagLink].self, from: dict[tag] ?? Data())) ?? []
        arr.removeAll { $0.url == url }
        if arr.isEmpty {
            dict.removeValue(forKey: tag)
        } else if let data = try? JSONEncoder().encode(arr) {
            dict[tag] = data
        }
        defaults.set(dict, forKey: Keys.tagLinksMap)
        NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
    }
    
    func clearLinks(for tag: String) {
        var dict = defaults.dictionary(forKey: Keys.tagLinksMap) as? [String: Data] ?? [:]
        dict.removeValue(forKey: tag)
        defaults.set(dict, forKey: Keys.tagLinksMap)
        NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
    }
    
    func updateLinkTitle(_ url: String, inTag tag: String, title: String) {
        var dict = defaults.dictionary(forKey: Keys.tagLinksMap) as? [String: Data] ?? [:]
        var arr = (try? JSONDecoder().decode([TagLink].self, from: dict[tag] ?? Data())) ?? []
        if let idx = arr.firstIndex(where: { $0.url == url }) {
            arr[idx].title = title
            if let data = try? JSONEncoder().encode(arr) {
                dict[tag] = data
                defaults.set(dict, forKey: Keys.tagLinksMap)
                NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
            }
        }
    }
    
    func updateLinkIcon(_ url: String, inTag tag: String, iconPNGData: Data?) {
        var dict = defaults.dictionary(forKey: Keys.tagLinksMap) as? [String: Data] ?? [:]
        var arr = (try? JSONDecoder().decode([TagLink].self, from: dict[tag] ?? Data())) ?? []
        if let idx = arr.firstIndex(where: { $0.url == url }) {
            arr[idx].iconPNGData = iconPNGData
            if let data = try? JSONEncoder().encode(arr) {
                dict[tag] = data
                defaults.set(dict, forKey: Keys.tagLinksMap)
                NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
            }
        }
    }
    
    func renameTag(from old: String, to new: String) {
        guard old != new, !new.isEmpty else { return }
        var list = tagList
        if let idx = list.firstIndex(of: old) {
            list[idx] = new
            tagList = list
        } else {
            return
        }
        var dict = defaults.dictionary(forKey: Keys.appTagsMap) as? [String: [String]] ?? [:]
        for (k, v) in dict {
            var arr = v
            var changed = false
            for i in 0..<arr.count {
                if arr[i] == old {
                    arr[i] = new
                    changed = true
                }
            }
            if changed {
                dict[k] = arr
            }
        }
        defaults.set(dict, forKey: Keys.appTagsMap)
        var urlMap = defaults.dictionary(forKey: Keys.tagURLsMap) as? [String: [String]] ?? [:]
        if let urls = urlMap[old] {
            urlMap[new] = urls
            urlMap.removeValue(forKey: old)
            defaults.set(urlMap, forKey: Keys.tagURLsMap)
        }
        if var linkMap = defaults.dictionary(forKey: Keys.tagLinksMap) as? [String: Data] {
            if let data = linkMap[old] {
                linkMap[new] = data
                linkMap.removeValue(forKey: old)
                defaults.set(linkMap, forKey: Keys.tagLinksMap)
            }
        }
        NotificationCenter.default.post(name: AppUIManager.Notifications.tagsChanged, object: nil)
    }
    
}
