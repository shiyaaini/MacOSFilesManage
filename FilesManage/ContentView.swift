//
//  ContentView.swift
//  FilesManage
//
//  Created by bolin on 2026/2/13.
//

import SwiftUI
import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

enum SortKey: String, CaseIterable {
    case name
    case date
    case size
}

struct ContentView: View {
    @StateObject private var fileManager = FileManager_Custom()
    @StateObject private var fileManagerRight = FileManager_Custom()
    @State private var refreshID = UUID()
    @State private var selectedItem: FileItem?
    @State private var selectedItemRight: FileItem?
    @State private var selectedSidebarItem: String?
    @State private var twoPaneEnabled = false
    @State private var searchTextLeft = ""
    @State private var searchTextRight = ""
    @State private var searchRecursiveLeft = false
    @State private var searchRecursiveRight = false
    @State private var selectedTag: String?
    @State private var sortKeyLeft: SortKey = .name
    @State private var sortAscendingLeft: Bool = true
    @State private var sortKeyRight: SortKey = .name
    @State private var sortAscendingRight: Bool = true
    @State private var splitRatio: CGFloat = 0.5
    @State private var isDraggingSplit: Bool = false
    @State private var dragStartRatio: CGFloat = 0.5
    @State private var blurEnabled: Bool = AppPreferences.shared.enableBlur
    @State private var activeIsRight: Bool = false
    @State private var previewWidth: CGFloat = CGFloat(AppPreferences.shared.previewPaneWidth)
    @State private var previewDragStart: CGFloat = CGFloat(AppPreferences.shared.previewPaneWidth)
    @State private var isDraggingPreview: Bool = false
    
    var activeManager: FileManager_Custom {
        activeIsRight ? fileManagerRight : fileManager
    }
    
    var body: some View {
        ZStack {
            if blurEnabled {
                VisualEffectViewRepresentable(material: .underWindowBackground, blending: .behindWindow)
                    .ignoresSafeArea()
            }
            NavigationSplitView {
                SidebarView(fileManager: fileManager, selectedItem: $selectedSidebarItem, selectedTag: $selectedTag)
                    .frame(minWidth: 200)
            } detail: {
                VStack(spacing: 0) {
                    ToolbarView(
                            fileManager: activeManager,
                        twoPaneEnabled: $twoPaneEnabled,
                        searchText: Binding(
                            get: { activeIsRight ? searchTextRight : searchTextLeft },
                            set: { new in
                                if activeIsRight { searchTextRight = new } else { searchTextLeft = new }
                            }
                        ),
                        searchRecursive: Binding(
                            get: { activeIsRight ? searchRecursiveRight : searchRecursiveLeft },
                            set: { new in
                                if activeIsRight { searchRecursiveRight = new } else { searchRecursiveLeft = new }
                            }
                        ),
                        sortKey: Binding(
                            get: { activeIsRight ? sortKeyRight : sortKeyLeft },
                            set: { new in
                                if activeIsRight { sortKeyRight = new } else { sortKeyLeft = new }
                            }
                        ),
                        sortAscending: Binding(
                            get: { activeIsRight ? sortAscendingRight : sortAscendingLeft },
                            set: { new in
                                if activeIsRight { sortAscendingRight = new } else { sortAscendingLeft = new }
                            }
                        )
                    )
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                BreadcrumbView(fileManager: fileManager)
                                FileListView(fileManager: fileManager, selectedItem: $selectedItem, searchText: $searchTextLeft, tagFilter: $selectedTag, sortKey: $sortKeyLeft, sortAscending: $sortAscendingLeft, onFocused: { activeIsRight = false }, searchRecursive: $searchRecursiveLeft)
                            }
                            .frame(width: twoPaneEnabled ? max(260, min(geo.size.width - 260, geo.size.width * splitRatio)) : max(260, geo.size.width - previewWidth - 1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(activeIsRight ? Color.clear : Color.accentColor.opacity(0.45), lineWidth: 1)
                            )
                            .simultaneousGesture(TapGesture().onEnded { activeIsRight = false })
                            if twoPaneEnabled {
                                ZStack {
                                    Color(nsColor: .separatorColor)
                                        .frame(width: 1)
                                        .padding(.vertical, 8)
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 8)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { g in
                                                    if !isDraggingSplit {
                                                        dragStartRatio = splitRatio
                                                        isDraggingSplit = true
                                                    }
                                                    let new = dragStartRatio + g.translation.width / geo.size.width
                                                    let minR = 260 / geo.size.width
                                                    let maxR = 1 - minR
                                                    splitRatio = max(minR, min(maxR, new))
                                                }
                                                .onEnded { _ in
                                                    isDraggingSplit = false
                                                    dragStartRatio = splitRatio
                                                }
                                        )
                                }
                                VStack(spacing: 0) {
                                    BreadcrumbView(fileManager: fileManagerRight)
                                    FileListView(fileManager: fileManagerRight, selectedItem: $selectedItemRight, searchText: $searchTextRight, tagFilter: .constant(nil), sortKey: $sortKeyRight, sortAscending: $sortAscendingRight, onFocused: { activeIsRight = true }, searchRecursive: $searchRecursiveRight)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(activeIsRight ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                                )
                                .simultaneousGesture(TapGesture().onEnded { activeIsRight = true })
                            } else {
                                if AppPreferences.shared.enablePreview {
                                    ZStack {
                                        Color(nsColor: .separatorColor)
                                            .frame(width: 1)
                                            .padding(.vertical, 8)
                                    }
                                    .frame(width: 1)
                                    .overlay(
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(width: 16)
                                            .contentShape(Rectangle())
                                            .onHover { h in
                                                if isDraggingPreview { return }
                                                if h { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
                                            }
                                            .gesture(
                                                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                                    .onChanged { g in
                                                        if !isDraggingPreview {
                                                            previewDragStart = previewWidth
                                                            isDraggingPreview = true
                                                        }
                                                        NSCursor.resizeLeftRight.set()
                                                        let minW: CGFloat = 220
                                                        let maxW: CGFloat = max(minW, geo.size.width - 260 - 11)
                                                        let newW = previewDragStart - g.translation.width
                                                        let clamped = round(max(minW, min(maxW, newW)))
                                                        withAnimation(.none) {
                                                            previewWidth = clamped
                                                        }
                                                    }
                                                    .onEnded { _ in
                                                        isDraggingPreview = false
                                                        previewDragStart = previewWidth
                                                        AppPreferences.shared.previewPaneWidth = Double(previewWidth)
                                                        NSCursor.arrow.set()
                                                    }
                                            )
                                    )
                                    .zIndex(10)
                                    ZStack {
                                        Color(nsColor: .controlBackgroundColor)
                                        PreviewPane(fileManager: fileManager, selectedItem: selectedItem)
                                    }
                                    .frame(width: previewWidth)
                                }
                            }
                            }
                }
            }
        }
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: AppUIManager.Notifications.themeChanged)) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppUIManager.Notifications.languageChanged)) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppUIManager.Notifications.blurChanged)) { notif in
            if let enabled = notif.object as? Bool {
                blurEnabled = enabled
                refreshID = UUID()
            }
        }
        .sheet(isPresented: Binding(get: { fileManager.isProcessing || fileManagerRight.isProcessing }, set: { _ in })) {
            VStack(spacing: 12) {
                Text((fileManager.isProcessing ? fileManager.processingTitle : fileManagerRight.processingTitle))
                    .font(.headline)
                if let prog = (fileManager.isProcessing ? fileManager.processingProgress : fileManagerRight.processingProgress) {
                    ProgressView(value: prog)
                        .frame(width: 240)
                } else {
                    ProgressView()
                        .frame(width: 240)
                }
                let detail = (fileManager.isProcessing ? fileManager.processingDetail : fileManagerRight.processingDetail)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .lineLimit(2)
                        .frame(width: 260)
                }
                Button("progress.cancel".localized) {
                    if fileManager.isProcessing { fileManager.cancelProcessing() }
                    if fileManagerRight.isProcessing { fileManagerRight.cancelProcessing() }
                }
            }
            .padding(16)
            .frame(width: 320)
        }
    }
}

struct ThumbnailView: View {
    let url: URL
    let icon: NSImage
    let size: CGFloat
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size, height: size)
            }
        }
        .onAppear { load() }
        .onChange(of: url) { _, _ in load() }
    }
    
    private func load() {
        guard url.isImageFile else {
            image = nil
            return
        }
        let key = url as NSURL
        if let cached = FileListView.imageCache.object(forKey: key) {
            image = cached
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            if let img = img {
                FileListView.imageCache.setObject(img, forKey: key)
            }
            DispatchQueue.main.async { image = img }
        }
    }
}
 
struct OpenWithMenu: View {
    @ObservedObject var fileManager: FileManager_Custom
    let item: FileItem
    
    var body: some View {
        let apps = fileManager.getApplications(for: item)
        let defaultApp = fileManager.getDefaultApplication(for: item)
        
        Menu("menu.openWith".localized) {
            if !apps.isEmpty {
                ForEach(apps, id: \.self) { appURL in
                    Button {
                        NSWorkspace.shared.open([item.url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                    } label: {
                        if appURL == defaultApp {
                            Text(name(for: appURL) + " (" + "openWith.default".localized + ")")
                        } else {
                            Text(name(for: appURL))
                        }
                    }
                }
                Divider()
            }
            
            Button("openWith.other".localized) {
                fileManager.openWith(item)
            }
            
            Divider()
            
            Menu("openWith.setDefault".localized) {
                if !apps.isEmpty {
                    ForEach(apps, id: \.self) { appURL in
                        Button(name(for: appURL)) {
                            fileManager.setDefaultApplication(at: appURL, for: item)
                        }
                    }
                    Divider()
                }
                Button("openWith.other".localized) {
                    fileManager.openWithSetDefault(item)
                }
            }
        }
    }
    
    private func name(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.localizedNameKey])
        return values?.localizedName ?? url.deletingPathExtension().lastPathComponent
    }
}
 
 
struct ToolbarView: View {
    @ObservedObject var fileManager: FileManager_Custom
    @Binding var twoPaneEnabled: Bool
    @State private var currentViewMode: String = "list"
    @State private var pathText: String = ""
    @Binding var searchText: String
    @Binding var searchRecursive: Bool
    @Binding var sortKey: SortKey
    @Binding var sortAscending: Bool
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
            Button(action: { fileManager.goBack() }) {
                Image(systemName: "chevron.left")
            }
            .disabled(!fileManager.canGoBack)
            .help("toolbar.back".localized)
            
            Button(action: { fileManager.goForward() }) {
                Image(systemName: "chevron.right")
            }
            .disabled(!fileManager.canGoForward)
            .help("toolbar.forward".localized)
            
            Button(action: { fileManager.goUp() }) {
                Image(systemName: "chevron.up")
            }
            .disabled(!fileManager.canGoUp)
            .help("toolbar.up".localized)
            
            Divider()
                .frame(height: 20)
            
            Button(action: { fileManager.goHome() }) {
                Image(systemName: "house")
            }
            .help("toolbar.home".localized)
            
            Button(action: { fileManager.selectFolder() }) {
                Image(systemName: "folder")
            }
            .help("toolbar.openFolder".localized)
            
            Button(action: { fileManager.openTerminal(at: FileItem(url: fileManager.currentPath)) }) {
                Image(systemName: "terminal")
            }
            .help("toolbar.openTerminal".localized)
            
            Divider()
                .frame(height: 20)
            
            Button(action: {
                let path = fileManager.currentPath.path
                AppPreferences.shared.setFolderViewMode("list", for: path)
                currentViewMode = "list"
                NotificationCenter.default.post(name: AppUIManager.Notifications.folderViewModeChanged, object: nil, userInfo: ["mode": "list"])
            }) {
                Image(systemName: currentViewMode == "list" ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
            }
            .help("toolbar.listView".localized)
            Button(action: {
                let path = fileManager.currentPath.path
                AppPreferences.shared.setFolderViewMode("grid", for: path)
                currentViewMode = "grid"
                NotificationCenter.default.post(name: AppUIManager.Notifications.folderViewModeChanged, object: nil, userInfo: ["mode": "grid"])
            }) {
                Image(systemName: currentViewMode == "grid" ? "square.grid.2x2.fill" : "square.grid.2x2")
            }
            .help("toolbar.gridView".localized)
            
            Button(action: { twoPaneEnabled.toggle() }) {
                Image(systemName: twoPaneEnabled ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
            }
            .help("toolbar.twoPane".localized)
            
            Spacer()
            
            TextField("search.placeholder".localized, text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 220)
            Button(action: { searchRecursive.toggle() }) {
                Image(systemName: searchRecursive ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
            }
            .help("toolbar.searchRecursive".localized)
            
            TextField("toolbar.path.placeholder".localized, text: $pathText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 320)
                .onSubmit {
                    goToPath(pathText)
                }
            
            Picker("sort.title".localized, selection: $sortKey) {
                Text("sort.name".localized).tag(SortKey.name)
                Text("sort.date".localized).tag(SortKey.date)
                Text("sort.size".localized).tag(SortKey.size)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            
            Button(action: { sortAscending.toggle() }) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
            }
            .help("toolbar.sortDirection".localized)
            
            Button(action: { fileManager.loadFiles() }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("toolbar.refresh".localized)
            }
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button(action: { fileManager.goBack() }) { Image(systemName: "chevron.left") }
                        .disabled(!fileManager.canGoBack)
                        .help("toolbar.back".localized)
                    Button(action: { fileManager.goForward() }) { Image(systemName: "chevron.right") }
                        .disabled(!fileManager.canGoForward)
                        .help("toolbar.forward".localized)
                    Button(action: { fileManager.goUp() }) { Image(systemName: "chevron.up") }
                        .disabled(!fileManager.canGoUp)
                        .help("toolbar.up".localized)
                    
                    Divider().frame(height: 20)
                    
                    Button(action: {
                        let path = fileManager.currentPath.path
                        AppPreferences.shared.setFolderViewMode("list", for: path)
                        currentViewMode = "list"
                        NotificationCenter.default.post(name: AppUIManager.Notifications.folderViewModeChanged, object: nil, userInfo: ["mode": "list"])
                    }) {
                        Image(systemName: currentViewMode == "list" ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    }
                    .help("toolbar.listView".localized)
                    Button(action: {
                        let path = fileManager.currentPath.path
                        AppPreferences.shared.setFolderViewMode("grid", for: path)
                        currentViewMode = "grid"
                        NotificationCenter.default.post(name: AppUIManager.Notifications.folderViewModeChanged, object: nil, userInfo: ["mode": "grid"])
                    }) {
                        Image(systemName: currentViewMode == "grid" ? "square.grid.2x2.fill" : "square.grid.2x2")
                    }
                    .help("toolbar.gridView".localized)
                    
                    Button(action: { fileManager.goHome() }) { Image(systemName: "house") }
                        .help("toolbar.home".localized)
                    Button(action: { fileManager.selectFolder() }) { Image(systemName: "folder") }
                        .help("toolbar.openFolder".localized)
                    Button(action: { fileManager.openTerminal(at: FileItem(url: fileManager.currentPath)) }) { Image(systemName: "terminal") }
                        .help("toolbar.openTerminal".localized)
                    
                    Divider().frame(height: 20)
                    
                    Button(action: { twoPaneEnabled.toggle() }) {
                        Image(systemName: twoPaneEnabled ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                    }
                    .help("toolbar.twoPane".localized)
                    
                    Spacer()
                    
                    Button(action: { fileManager.loadFiles() }) { Image(systemName: "arrow.clockwise") }
                        .help("toolbar.refresh".localized)
                }
                HStack(spacing: 12) {
                    TextField("search.placeholder".localized, text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minWidth: 160, idealWidth: 220, maxWidth: 260)
                    Button(action: { searchRecursive.toggle() }) {
                        Image(systemName: searchRecursive ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                    }
                    .help("toolbar.searchRecursive".localized)
                    TextField("toolbar.path.placeholder".localized, text: $pathText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minWidth: 240, idealWidth: 320, maxWidth: 420)
                        .onSubmit { goToPath(pathText) }
                    Picker("sort.title".localized, selection: $sortKey) {
                        Text("sort.name".localized).tag(SortKey.name)
                        Text("sort.date".localized).tag(SortKey.date)
                        Text("sort.size".localized).tag(SortKey.size)
                    }
                    .pickerStyle(.segmented)
                    .frame(minWidth: 200, idealWidth: 220)
                    Button(action: { sortAscending.toggle() }) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                    }
                    .help("toolbar.sortDirection".localized)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            let path = fileManager.currentPath.path
            currentViewMode = AppPreferences.shared.folderViewMode(for: path)
            pathText = path
        }
        .onChange(of: fileManager.currentPath) { _, newPath in
            currentViewMode = AppPreferences.shared.folderViewMode(for: newPath.path)
            pathText = newPath.path
        }
        .onReceive(NotificationCenter.default.publisher(for: AppUIManager.Notifications.folderViewModeChanged)) { notif in
            let path = fileManager.currentPath.path
            if let mode = notif.userInfo?["mode"] as? String {
                currentViewMode = mode
            } else {
                currentViewMode = AppPreferences.shared.folderViewMode(for: path)
            }
        }
    }
    
    private func goToPath(_ s: String) {
        let raw = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let expanded = (raw as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        let fm = FileManager.default
        if fm.fileExists(atPath: expanded, isDirectory: &isDir) {
            if isDir.boolValue {
                fileManager.navigateTo(URL(fileURLWithPath: expanded))
            } else {
                let parent = URL(fileURLWithPath: expanded).deletingLastPathComponent()
                fileManager.navigateTo(parent)
            }
        } else if let u = URL(string: raw), u.isFileURL {
            let p = u.path
            if fm.fileExists(atPath: p, isDirectory: &isDir) {
                if isDir.boolValue {
                    fileManager.navigateTo(URL(fileURLWithPath: p))
                } else {
                    let parent = URL(fileURLWithPath: p).deletingLastPathComponent()
                    fileManager.navigateTo(parent)
                }
            } else {
                showPathError()
            }
        } else {
            showPathError()
        }
    }
    
    private func showPathError() {
        let alert = NSAlert()
        alert.messageText = "toolbar.path.error".localized
        alert.addButton(withTitle: "common.ok".localized)
        alert.runModal()
    }
}

struct BreadcrumbView: View {
    @ObservedObject var fileManager: FileManager_Custom
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(pathComponents, id: \.path) { component in
                    Button(action: {
                        fileManager.navigateTo(component)
                    }) {
                        Text(component.lastPathComponent)
                            .foregroundColor(Color.themeText)
                    }
                    .buttonStyle(.plain)
                    
                    if component != fileManager.currentPath {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.themeSecondaryText)
                    }
                }
                Spacer(minLength: 8)
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(fileManager.currentPath.path, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .help("breadcrumb.copyPath".localized)
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(height: 30)
    }
    
    private var pathComponents: [URL] {
        var components: [URL] = []
        var current = fileManager.currentPath
        
        while current.path != "/" {
            components.insert(current, at: 0)
            current = current.deletingLastPathComponent()
        }
        
        return components
    }
}

struct SidebarView: View {
    @ObservedObject var fileManager: FileManager_Custom
    @Binding var selectedItem: String?
    @Binding var selectedTag: String?
    @State private var refreshID = UUID()
    @State private var volumes: [VolumeInfo] = []
    @State private var showFavorites: Bool = true
    @State private var showLocations: Bool = true
    @State private var showDisks: Bool = true
    @State private var showTags: Bool = true
    
    var body: some View {
        List(selection: $selectedItem) {
            Section {
                if showFavorites {
                    SidebarItem(id: "desktop", icon: "desktopcomputer", title: "sidebar.desktop".localized) {
                        selectedItem = "desktop"
                    }
                    SidebarItem(id: "documents", icon: "doc", title: "sidebar.documents".localized) {
                        selectedItem = "documents"
                    }
                    SidebarItem(id: "downloads", icon: "arrow.down.circle", title: "sidebar.downloads".localized) {
                        selectedItem = "downloads"
                    }
                    SidebarItem(id: "pictures", icon: "photo", title: "sidebar.pictures".localized) {
                        selectedItem = "pictures"
                    }
                    SidebarItem(id: "music", icon: "music.note", title: "sidebar.music".localized) {
                        selectedItem = "music"
                    }
                }
            } header: {
                HStack {
                    Button {
                        showFavorites.toggle()
                    } label: {
                        Label("sidebar.favorites".localized, systemImage: showFavorites ? "chevron.down" : "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            
            Section {
                if showLocations {
                    SidebarItem(id: "home", icon: "house", title: "sidebar.home".localized) {
                        selectedItem = "home"
                    }
                    SidebarItem(id: "applications", icon: "app", title: "sidebar.applications".localized) {
                        selectedItem = "applications"
                    }
                }
            } header: {
                HStack {
                    Button {
                        showLocations.toggle()
                    } label: {
                        Label("sidebar.locations".localized, systemImage: showLocations ? "chevron.down" : "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            
            Section {
                if showDisks {
                    ForEach(volumes) { v in
                        HStack(spacing: 10) {
                            Image(systemName: "externaldrive")
                            VStack(alignment: .leading, spacing: 6) {
                                Text(v.name)
                                    .font(.subheadline)
                                ProgressView(value: v.usedRatio)
                                HStack {
                                    Text("disk.used".localized + ": " + v.formattedUsed)
                                    Spacer()
                                    Text("disk.free".localized + ": " + v.formattedFree)
                                    Spacer()
                                    Text("disk.total".localized + ": " + v.formattedTotal)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = nil
                            selectedTag = nil
                            fileManager.navigateTo(v.url)
                        }
                    }
                }
            } header: {
                HStack {
                    Button {
                        showDisks.toggle()
                    } label: {
                        Label("sidebar.disks".localized, systemImage: showDisks ? "chevron.down" : "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: {
                        volumes = VolumeInfo.fetch()
                        refreshID = UUID()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("toolbar.refresh".localized)
                    .buttonStyle(.plain)
                }
            }
            
            Section {
                if showTags {
                    ForEach(AppPreferences.shared.tagList, id: \.self) { tag in
                        TagItem(tag: tag, selectedItem: $selectedItem)
                    }
                }
            } header: {
                HStack {
                    Button {
                        showTags.toggle()
                    } label: {
                        Label("sidebar.tags".localized, systemImage: showTags ? "chevron.down" : "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selectedItem) { oldID, newID in
            guard let id = newID else { return }
            if id == "home" {
                fileManager.goHome()
                return
            }
            if id.hasPrefix("tag:") {
                selectedTag = String(id.dropFirst(4))
                fileManager.navigateTo(URL(fileURLWithPath: "/Applications"))
                return
            } else {
                selectedTag = nil
            }
            if let url = sidebarURL(for: id) {
                fileManager.navigateTo(url)
            }
        }
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: AppUIManager.Notifications.tagsChanged)) { _ in
            refreshID = UUID()
        }
        .onAppear {
            volumes = VolumeInfo.fetch()
        }
    }
    
    private func sidebarURL(for id: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch id {
        case "desktop": return home.appendingPathComponent("Desktop")
        case "documents": return home.appendingPathComponent("Documents")
        case "downloads": return home.appendingPathComponent("Downloads")
        case "pictures": return home.appendingPathComponent("Pictures")
        case "music": return home.appendingPathComponent("Music")
        case "applications": return URL(fileURLWithPath: "/Applications")
        default: return nil
        }
    }
}
 
 struct VolumeInfo: Identifiable {
     let id: String
     let url: URL
     let name: String
     let total: Int64
     let available: Int64
     var used: Int64 { max(0, total - available) }
     var usedRatio: Double { total > 0 ? Double(used) / Double(total) : 0 }
     var formattedUsed: String { ByteCountFormatter.string(fromByteCount: used, countStyle: .file) }
     var formattedFree: String { ByteCountFormatter.string(fromByteCount: available, countStyle: .file) }
     var formattedTotal: String { ByteCountFormatter.string(fromByteCount: total, countStyle: .file) }
     
     static func fetch() -> [VolumeInfo] {
         let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
         let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) ?? []
         var list: [VolumeInfo] = []
         for u in urls {
             let vals = try? u.resourceValues(forKeys: Set(keys))
             let name = vals?.volumeName ?? u.lastPathComponent
             let total = Int64(vals?.volumeTotalCapacity ?? 0)
             let available = Int64(vals?.volumeAvailableCapacity ?? 0)
             let id = u.path
             list.append(VolumeInfo(id: id, url: u, name: name, total: total, available: available))
         }
         return list
     }
 }

struct SidebarItem: View {
    let id: String
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(Color.themeText)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .tag(id)
    }
}

struct TagItem: View {
    let tag: String
    @Binding var selectedItem: String?
    
    var body: some View {
        HStack {
            Label(tag, systemImage: "tag")
                .foregroundColor(Color.themeText)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = "tag:\(tag)"
        }
        .tag("tag:\(tag)")
        .contextMenu {
            Button("tag.rename".localized) { renameTagPrompt(old: tag) }
            Button("tag.delete".localized, role: .destructive) { AppPreferences.shared.removeTag(tag) }
            Divider()
            Button("tag.url.add".localized) { addURLPrompt(for: tag) }
            let links = AppPreferences.shared.links(for: tag)
            if !links.isEmpty {
                Menu("tag.url.open".localized) {
                    ForEach(links, id: \.url) { l in
                        Button {
                            if let link = URL(string: l.url) {
                                NSWorkspace.shared.open(link)
                            }
                        } label: {
                            HStack {
                                if let img = l.nsImage {
                                    Image(nsImage: img)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .cornerRadius(3)
                                }
                                Text(l.title.isEmpty ? l.url : l.title)
                            }
                        }
                    }
                }
                Menu("tag.url.remove".localized) {
                    ForEach(links, id: \.url) { l in
                        Button(l.title.isEmpty ? l.url : l.title) {
                            AppPreferences.shared.removeLink(byURL: l.url, fromTag: tag)
                        }
                    }
                    Divider()
                    Button("tag.url.clear".localized) {
                        AppPreferences.shared.clearLinks(for: tag)
                    }
                }
            }
        }
    }
    
    private func renameTagPrompt(old: String) {
        let alert = NSAlert()
        alert.messageText = "tag.rename.title".localized
        alert.informativeText = "tag.rename.prompt".localized
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        tf.stringValue = old
        alert.accessoryView = tf
        alert.addButton(withTitle: "common.ok".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            let name = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            AppPreferences.shared.renameTag(from: old, to: name)
        }
    }
    
    private func addURLPrompt(for tag: String) {
        let alert = NSAlert()
        alert.messageText = "tag.url.create.title".localized
        alert.informativeText = "tag.url.create.prompt".localized
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        tf.placeholderString = "tag.url.placeholder".localized
        alert.accessoryView = tf
        alert.addButton(withTitle: "common.ok".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            var s = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return }
            if !(s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://")) {
                s = "https://\(s)"
            }
            guard URL(string: s) != nil else { return }
            fetchURLMeta(s) { title, icon in
                if let t = title {
                    let link = AppPreferences.TagLink(url: s, title: t, iconPNGData: icon)
                    AppPreferences.shared.addLink(link, toTag: tag)
                } else {
                    manualLinkPrompt(url: s, for: tag)
                }
            }
        }
    }
    
    private func manualLinkPrompt(url: String, for tag: String) {
        let alert = NSAlert()
        alert.messageText = "tag.link.manual.title".localized
        alert.informativeText = "tag.link.manual.prompt".localized
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        tf.placeholderString = "tag.link.title.placeholder".localized
        alert.accessoryView = tf
        alert.addButton(withTitle: "common.ok".localized)
        alert.addButton(withTitle: "tag.link.chooseIcon".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            let title = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let link = AppPreferences.TagLink(url: url, title: title.isEmpty ? url : title, iconPNGData: nil)
            AppPreferences.shared.addLink(link, toTag: tag)
        } else if resp == .alertSecondButtonReturn {
            let title = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let panel = NSOpenPanel()
            panel.allowedFileTypes = ["png", "jpg", "jpeg", "icns", "gif", "tiff"]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            if panel.runModal() == .OK, let u = panel.url, let img = NSImage(contentsOf: u), let data = img.pngData() {
                let link = AppPreferences.TagLink(url: url, title: title.isEmpty ? url : title, iconPNGData: data)
                AppPreferences.shared.addLink(link, toTag: tag)
            } else {
                let link = AppPreferences.TagLink(url: url, title: title.isEmpty ? url : title, iconPNGData: nil)
                AppPreferences.shared.addLink(link, toTag: tag)
            }
        }
    }
    
    private func fetchURLMeta(_ urlString: String, completion: @escaping (String?, Data?) -> Void) {
        guard let u = URL(string: urlString) else {
            completion(nil, nil)
            return
        }
        URLSession.shared.dataTask(with: u) { data, _, _ in
            var title: String?
            var iconData: Data?
            if let d = data, let html = String(data: d, encoding: .utf8) {
                if let t = match(html, pattern: "(?is)<title[^>]*>(.*?)</title>")?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    title = t
                }
                if let href = match(html, pattern: "(?is)<link[^>]*rel=[\"'][^\"']*icon[^\"']*[\"'][^>]*href=[\"']([^\"']+)[\"']"),
                   let iconURL = URL(string: href, relativeTo: u) {
                    if let d2 = try? Data(contentsOf: iconURL), let png = normalizeToPNG(d2) {
                        iconData = png
                    }
                }
            }
            if iconData == nil {
                let base = URL(string: "/favicon.ico", relativeTo: u)
                if let fav = base, let d3 = try? Data(contentsOf: fav), let png = normalizeToPNG(d3) {
                    iconData = png
                }
            }
            DispatchQueue.main.async {
                completion(title, iconData)
            }
        }.resume()
    }
    
    private func match(_ text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        if let m = regex.firstMatch(in: text, options: [], range: range), m.numberOfRanges >= 2 {
            let r = m.range(at: 1)
            if let swiftRange = Range(r, in: text) {
                return String(text[swiftRange])
            }
        }
        return nil
    }
    
    
    private func normalizeToPNG(_ data: Data) -> Data? {
        if let img = NSImage(data: data) {
            return img.pngData()
        }
        return nil
    }
}

struct FileListView: View {
    @ObservedObject var fileManager: FileManager_Custom
    @Binding var selectedItem: FileItem?
    @Binding var searchText: String
    @Binding var tagFilter: String?
    @Binding var sortKey: SortKey
    @Binding var sortAscending: Bool
    var onFocused: (() -> Void)?
    @Binding var searchRecursive: Bool
    @State private var selectedIDs: Set<FileItem.ID> = []
    @State private var propertiesItem: FileItem?
    @State private var keyMonitor: Any?
    @State private var typeAheadBuffer: String = ""
    @State private var typeAheadTimer: Timer?
    @State private var lastSelectedIndex: Int?
    @State private var previewTimer: Timer?
    @State private var viewMode: String = "list"
    @State private var gridItemSize: CGFloat = 96
    @State private var gridColumnCount: Int = 1
    @State private var linksRefreshID: UUID = UUID()
    
    static let imageCache = NSCache<NSURL, NSImage>()
    
    var body: some View {
        Group {
            if fileManager.isLoading {
                ProgressView("file.loading".localized)
            } else if let error = fileManager.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("file.noAccess".localized)
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("file.requestAccess".localized) {
                        fileManager.requestAccess(for: fileManager.currentPath)
                    }
                }
                .padding()
            } else if displayFiles.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 60))
                        .foregroundColor(Color.themeAccent)
                    Text("file.empty".localized)
                        .foregroundColor(Color.themeSecondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onFocused?() }
                .contextMenu {
                    Button("menu.paste".localized) { fileManager.pasteClipboard() }
                        .disabled(!fileManager.canPaste)
                    Divider()
                    Button("menu.newFolder".localized) { fileManager.createFolder() }
                    Button("menu.newFile".localized) { fileManager.createEmptyFile() }
                    Divider()
                    Button("menu.terminal".localized) { fileManager.openTerminal(at: FileItem(url: fileManager.currentPath)) }
                }
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                    fileManager.handleDroppedProviders(providers)
                    return true
                }
            } else {
                currentContent()
                .id(linksRefreshID)
                .contextMenu {
                    Button("menu.copy".localized) {
                        let sel = displayFiles.filter { selectedIDs.contains($0.id) }
                        if sel.isEmpty, let item = selectedItem { fileManager.copyToClipboard(item) } else { fileManager.copyToClipboard(sel) }
                    }
                    .disabled(selectedIDs.isEmpty && selectedItem == nil)
                    Button("menu.cut".localized) {
                        let sel = displayFiles.filter { selectedIDs.contains($0.id) }
                        if sel.isEmpty, let item = selectedItem { fileManager.cutToClipboard(item) } else { fileManager.cutToClipboard(sel) }
                    }
                    .disabled(selectedIDs.isEmpty && selectedItem == nil)
                    Button("menu.paste".localized) { fileManager.pasteClipboard() }
                        .disabled(!fileManager.canPaste)
                    Divider()
                    Button("menu.rename".localized) {
                        if let item = selectedItem { fileManager.rename(item) }
                    }
                    .disabled(!(selectedItem != nil && selectedIDs.count <= 1))
                    Button("menu.newFolder".localized) { fileManager.createFolder() }
                    Button("menu.newFile".localized) { fileManager.createEmptyFile() }
                    Divider()
                    Button("menu.terminal".localized) { fileManager.openTerminal(at: FileItem(url: fileManager.currentPath)) }
                }
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                    fileManager.handleDroppedProviders(providers)
                    return true
                }
                .simultaneousGesture(TapGesture().onEnded { onFocused?() })
                .onChange(of: selectedIDs) { _, newSet in
                    previewTimer?.invalidate()
                    if newSet.count == 1, let only = newSet.first, let item = displayFiles.first(where: { $0.id == only }) {
                        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                            selectedItem = item
                        }
                    } else {
                        selectedItem = nil
                    }
                }
                .onChange(of: fileManager.currentPath) { _, newPath in
                    let path = newPath.path
                    viewMode = AppPreferences.shared.folderViewMode(for: path)
                    gridItemSize = CGFloat(AppPreferences.shared.folderGridSize(for: path))
                }
                .onReceive(NotificationCenter.default.publisher(for: AppUIManager.Notifications.folderViewModeChanged)) { notif in
                    if let mode = notif.userInfo?["mode"] as? String {
                        viewMode = mode
                        AppPreferences.shared.setFolderViewMode(mode, for: fileManager.currentPath.path)
                    } else {
                        let path = fileManager.currentPath.path
                        viewMode = AppPreferences.shared.folderViewMode(for: path)
                    }
                }
                .onAppear {
                    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { evt in
                        if evt.type == .keyDown {
                            handleKeyDown(evt)
                        } else if evt.type == .scrollWheel {
                            handleScrollWheel(evt)
                        }
                        return evt
                    }
                    let path = fileManager.currentPath.path
                    viewMode = AppPreferences.shared.folderViewMode(for: path)
                    gridItemSize = CGFloat(AppPreferences.shared.folderGridSize(for: path))
                }
                .onDisappear {
                    if let m = keyMonitor {
                        NSEvent.removeMonitor(m)
                        keyMonitor = nil
                    }
                    typeAheadTimer?.invalidate()
                    typeAheadTimer = nil
                    typeAheadBuffer = ""
                }
                .onChange(of: searchText) { _, _ in
                    selectedIDs.removeAll()
                    selectedItem = nil
                }
                .onChange(of: tagFilter) { _, _ in
                    selectedIDs.removeAll()
                    selectedItem = nil
                }
                .onReceive(NotificationCenter.default.publisher(for: AppUIManager.Notifications.tagsChanged)) { _ in
                    linksRefreshID = UUID()
                }
                .sheet(item: $propertiesItem) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.name).font(.headline)
                        HStack {
                            Text("file.size".localized + ":")
                            Text(item.formattedSize)
                        }
                        HStack {
                            Text("file.modifiedDate".localized + ":")
                            Text(item.formattedDate)
                        }
                        HStack {
                            Text("file.path".localized + ":")
                            Text(item.url.path)
                        }
                        HStack {
                            Text("file.type".localized + ":")
                            Text(item.isDirectory ? "preview.folder".localized : item.url.pathExtension.isEmpty ? "file.file".localized : item.url.pathExtension.uppercased())
                        }
                        HStack {
                            Spacer()
                            Button("common.close".localized) { propertiesItem = nil }
                        }
                    }
                    .padding(16)
                    .frame(width: 420)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBackground)
    }
    
    private var displayFiles: [FileItem] {
        var list = fileManager.files
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            let lq = q.lowercased()
            if searchRecursive && tagFilter == nil {
                var matches: [FileItem] = []
                let fm = FileManager.default
                if let en = fm.enumerator(at: fileManager.currentPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles], errorHandler: nil) {
                    var count = 0
                    let maxResults = 500
                    for case let u as URL in en {
                        if u.lastPathComponent.lowercased().contains(lq) {
                            matches.append(FileItem(url: u))
                            count += 1
                            if count >= maxResults { break }
                        }
                    }
                }
                list = matches
            } else {
                list = list.filter { $0.name.lowercased().contains(lq) }
            }
        }
        var linkItems: [FileItem] = []
        if let tag = tagFilter, !tag.isEmpty {
            list = list.filter {
                $0.url.pathExtension.lowercased() == "app" &&
                AppPreferences.shared.tags(for: $0.url.path).contains(tag)
            }
            let links = AppPreferences.shared.links(for: tag)
            linkItems = links.compactMap {
                guard let u = URL(string: $0.url) else { return nil }
                let icon = $0.nsImage ?? (NSImage(systemSymbolName: "link", accessibilityDescription: nil))
                return FileItem(linkURL: u, title: $0.title.isEmpty ? $0.url : $0.title, icon: icon)
            }
            if !q.isEmpty {
                linkItems = linkItems.filter { $0.name.lowercased().contains(q.lowercased()) }
            }
        }
        func sortByName(_ a: FileItem, _ b: FileItem) -> Bool {
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        func sortByDate(_ a: FileItem, _ b: FileItem) -> Bool {
            let da = a.modificationDate ?? .distantPast
            let db = b.modificationDate ?? .distantPast
            return da < db
        }
        func sortBySize(_ a: FileItem, _ b: FileItem) -> Bool {
            a.size < b.size
        }
        let comparator: (FileItem, FileItem) -> Bool = {
            switch sortKey {
            case .name: return sortByName
            case .date: return sortByDate
            case .size: return sortBySize
            }
        }()
        let dirs = list.filter { $0.isDirectory }
        let files = list.filter { !$0.isDirectory }
        let sd = dirs.sorted(by: comparator)
        let sf = files.sorted(by: comparator)
        let combined = linkItems.isEmpty ? (sd + sf) : (linkItems.sorted(by: comparator) + sd + sf)
        return sortAscending ? combined : combined.reversed()
    }
    
    private var shouldShowPathColumn: Bool {
        searchRecursive && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func relativeParentPath(for item: FileItem) -> String {
        if !shouldShowPathColumn { return "" }
        if item.url.isFileURL {
            let parent = item.url.deletingLastPathComponent().path
            let root = fileManager.currentPath.path
            if parent.hasPrefix(root) {
                var rel = String(parent.dropFirst(root.count))
                if rel.hasPrefix("/") { rel.removeFirst() }
                return rel.isEmpty ? "." : rel
            } else {
                return parent
            }
        } else {
            return item.url.absoluteString
        }
    }
    
    @ViewBuilder
    func currentContent() -> some View {
        if viewMode == "grid" {
            gridContent()
        } else {
            listContent()
        }
    }
    
    @ViewBuilder
    private func gridContent() -> some View {
        GeometryReader { geo in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: gridItemSize + 80), spacing: 16)], spacing: 16) {
                    ForEach(displayFiles) { item in
                        VStack(spacing: 8) {
                            ThumbnailView(url: item.url, icon: item.icon, size: gridItemSize)
                            Text(item.name)
                                .frame(maxWidth: gridItemSize + 80, alignment: .center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedIDs.contains(item.id) ? Color.blue.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedIDs.contains(item.id) ? Color.blue.opacity(0.35) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onFocused?()
                            if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
                                fileManager.openFile(item)
                            } else {
                                handleRowClick(item)
                            }
                        }
                        .contextMenu {
                            contextMenuContent(for: item)
                        }
                    }
                }
                .padding(12)
            }
            .background(
                DragSourceBridge(getURLs: {
                    let sel = displayFiles.filter { selectedIDs.contains($0.id) }
                    return fileManager.prepareItemsForDrag(sel)
                })
                .allowsHitTesting(false)
            )
            .onAppear { updateColumnCount(geo.size.width) }
            .onChange(of: geo.size.width) { _, newW in updateColumnCount(newW) }
            .onChange(of: gridItemSize) { _, _ in updateColumnCount(geo.size.width) }
        }
    }
    
    @ViewBuilder
    private func listContent() -> some View {
        Table(displayFiles, selection: $selectedIDs) {
            TableColumn("file.name".localized) { item in
                HStack(spacing: 8) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(item.name)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onFocused?()
                    if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
                        fileManager.openFile(item)
                    } else {
                        handleRowClick(item)
                    }
                }
                .contextMenu {
                    contextMenuContent(for: item)
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("file.modifiedDate".localized) { item in
                Text(item.formattedDate)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onFocused?()
                    if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
                        fileManager.openFile(item)
                    } else {
                        handleRowClick(item)
                    }
                    }
                    .contextMenu {
                        contextMenuContent(for: item)
                    }
            }
            .width(min: 150, ideal: 180)
            
            TableColumn("file.size".localized) { item in
                Text(item.formattedSize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onFocused?()
                        fileManager.openFile(item)
                    }
                    .onTapGesture {
                        onFocused?()
                        handleRowClick(item)
                    }
                    .contextMenu {
                        contextMenuContent(for: item)
                    }
            }
            .width(min: 80, ideal: 100)
            
            if shouldShowPathColumn {
                TableColumn("file.path".localized) { item in
                    Text(relativeParentPath(for: item))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onFocused?()
                            fileManager.openFile(item)
                        }
                        .onTapGesture {
                            onFocused?()
                            handleRowClick(item)
                        }
                }
                .width(min: 200, ideal: 380)
            }
            
            TableColumn("") { item in
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
                            fileManager.openFile(item)
                        } else {
                            handleRowClick(item)
                        }
                    }
                    .contextMenu {
                        contextMenuContent(for: item)
                    }
            }
            .width(min: 100, ideal: 800)
        }
        .background(
            DragSourceBridge(getURLs: {
                let sel = displayFiles.filter { selectedIDs.contains($0.id) }
                return fileManager.prepareItemsForDrag(sel)
            })
            .allowsHitTesting(false)
        )
    }
    
    func handleKeyDown(_ event: NSEvent) {
        if viewMode == "grid" {
            let code = event.keyCode
            if code == 123 || code == 124 || code == 125 || code == 126 {
                let list = displayFiles
                guard !list.isEmpty else { return }
                let idx = lastSelectedIndex ?? (selectedIDs.first.flatMap { sel in list.firstIndex(where: { $0.id == sel }) } ?? 0)
                var delta = 0
                if code == 123 { delta = -1 }
                else if code == 124 { delta = 1 }
                else if code == 125 { delta = max(1, gridColumnCount) }
                else if code == 126 { delta = -max(1, gridColumnCount) }
                let newIndex = max(0, min(list.count - 1, idx + delta))
                let item = list[newIndex]
                selectedIDs = [item.id]
                selectedItem = item
                lastSelectedIndex = newIndex
                return
            }
        }
        let code = event.keyCode
        if code == 51 || code == 117 {
            let sel = displayFiles.filter { selectedIDs.contains($0.id) }
            if sel.isEmpty, let item = selectedItem {
                fileManager.moveToTrash(item)
            } else {
                fileManager.moveToTrash(sel)
            }
            return
        }
        if code == 96 {
            fileManager.loadFiles()
            return
        }
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return }
        if event.modifierFlags.contains(.command) {
            let s = chars
            if s.lowercased() == "c" {
                let sel = displayFiles.filter { selectedIDs.contains($0.id) }
                if sel.isEmpty, let item = selectedItem {
                    fileManager.copyToClipboard(item)
                } else {
                    fileManager.copyToClipboard(sel)
                }
                return
            } else if s.lowercased() == "x" {
                let sel = displayFiles.filter { selectedIDs.contains($0.id) }
                if sel.isEmpty, let item = selectedItem {
                    fileManager.cutToClipboard(item)
                } else {
                    fileManager.cutToClipboard(sel)
                }
                return
            } else if s.lowercased() == "v" {
                fileManager.pasteClipboard()
                return
            } else if s.lowercased() == "a" {
                selectedIDs = Set(displayFiles.map { $0.id })
                selectedItem = nil
                return
            }
            if s == "1" {
                viewMode = "list"
                AppPreferences.shared.setFolderViewMode("list", for: fileManager.currentPath.path)
                return
            } else if s == "2" {
                viewMode = "grid"
                AppPreferences.shared.setFolderViewMode("grid", for: fileManager.currentPath.path)
                return
            } else if s == "=" || s == "+" {
                let newSize = min(gridItemSize + 16, 256)
                gridItemSize = newSize
                AppPreferences.shared.setFolderGridSize(Double(newSize), for: fileManager.currentPath.path)
                return
            } else if s == "-" {
                let newSize = max(gridItemSize - 16, 48)
                gridItemSize = newSize
                AppPreferences.shared.setFolderGridSize(Double(newSize), for: fileManager.currentPath.path)
                return
            } else if s == "0" {
                gridItemSize = 96
                AppPreferences.shared.setFolderGridSize(96.0, for: fileManager.currentPath.path)
                return
            }
        }
        let s = chars.lowercased()
        guard s.count == 1 else { return }
        let c = s.first!
        let allowed = "abcdefghijklmnopqrstuvwxyz0123456789"
        guard allowed.contains(c) else { return }
        
        typeAheadTimer?.invalidate()
        typeAheadBuffer.append(c)
        typeAheadTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
            typeAheadBuffer = ""
        }
        
        let list = displayFiles
        guard !list.isEmpty else { return }
        
        var startIndex = 0
        if typeAheadBuffer.count == 1, let sel = selectedIDs.first, let idx = list.firstIndex(where: { $0.id == sel }) {
            startIndex = (idx + 1) % list.count
        }
        
        func match(_ name: String) -> Bool {
            name.lowercased().hasPrefix(typeAheadBuffer)
        }
        
        var found: FileItem?
        if startIndex < list.count {
            found = list[startIndex...].first(where: { match($0.name) })
        }
        if found == nil {
            found = list[0..<startIndex].first(where: { match($0.name) })
        }
        if let f = found {
            selectedIDs = [f.id]
            selectedItem = f
            lastSelectedIndex = list.firstIndex(where: { $0.id == f.id })
        }
    }
    
    private func updateColumnCount(_ width: CGFloat) {
        let cell = gridItemSize + 80
        let spacing: CGFloat = 16
        let contentWidth = max(0, width - 24)
        let count = max(1, Int(floor((contentWidth + spacing) / (cell + spacing))))
        if gridColumnCount != count {
            gridColumnCount = count
        }
    }
    
    func handleScrollWheel(_ event: NSEvent) {
        guard viewMode == "grid" else { return }
        guard event.modifierFlags.contains(.command) else { return }
        let dy = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
        if dy == 0 { return }
        let step: CGFloat = 8
        if dy > 0 {
            let newSize = min(gridItemSize + step, 256)
            gridItemSize = newSize
            AppPreferences.shared.setFolderGridSize(Double(newSize), for: fileManager.currentPath.path)
        } else {
            let newSize = max(gridItemSize - step, 48)
            gridItemSize = newSize
            AppPreferences.shared.setFolderGridSize(Double(newSize), for: fileManager.currentPath.path)
        }
    }
    
    func handleRowClick(_ item: FileItem) {
        onFocused?()
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        let list = displayFiles
        guard let idx = list.firstIndex(where: { $0.id == item.id }) else { return }
        
        if flags.contains(.shift) {
            let anchor = lastSelectedIndex ?? idx
            let lower = min(anchor, idx)
            let upper = max(anchor, idx)
            let ids = Set(list[lower...upper].map { $0.id })
            selectedIDs = ids
            lastSelectedIndex = anchor
            selectedItem = nil
        } else if flags.contains(.command) {
            if selectedIDs.contains(item.id) {
                selectedIDs.remove(item.id)
            } else {
                selectedIDs.insert(item.id)
            }
            lastSelectedIndex = idx
            selectedItem = nil
        } else {
            selectedIDs = [item.id]
            lastSelectedIndex = idx
            selectedItem = nil
        }
    }
    
    func createTagPrompt() {
        let alert = NSAlert()
        alert.messageText = "tag.create.title".localized
        alert.informativeText = "tag.create.prompt".localized
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        tf.placeholderString = "tag.name.placeholder".localized
        alert.accessoryView = tf
        alert.addButton(withTitle: "common.ok".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            let name = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            AppPreferences.shared.addTag(name)
        }
    }
    
    func renameLinkTitle(_ item: FileItem) {
        guard let tag = tagFilter, !tag.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "menu.link.renameTitle".localized
        alert.informativeText = item.url.absoluteString
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        tf.stringValue = item.name
        alert.accessoryView = tf
        alert.addButton(withTitle: "common.ok".localized)
        alert.addButton(withTitle: "common.cancel".localized)
        if alert.runModal() == .alertFirstButtonReturn {
            let newTitle = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            AppPreferences.shared.updateLinkTitle(item.url.absoluteString, inTag: tag, title: newTitle.isEmpty ? item.url.absoluteString : newTitle)
        }
    }
    
    func changeLinkIcon(_ item: FileItem) {
        guard let tag = tagFilter, !tag.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["png", "jpg", "jpeg", "icns", "gif", "tiff"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let u = panel.url, let img = NSImage(contentsOf: u), let data = img.pngData() {
            AppPreferences.shared.updateLinkIcon(item.url.absoluteString, inTag: tag, iconPNGData: data)
        }
    }
    
    @ViewBuilder
    func contextMenuContent(for item: FileItem) -> some View {
        Button("menu.copy".localized) {
            let sel = displayFiles.filter { selectedIDs.contains($0.id) }
            if sel.count > 1 { fileManager.copyToClipboard(sel) } else { fileManager.copyToClipboard(item) }
        }
        Button("menu.cut".localized) {
            let sel = displayFiles.filter { selectedIDs.contains($0.id) }
            if sel.count > 1 { fileManager.cutToClipboard(sel) } else { fileManager.cutToClipboard(item) }
        }
        Button("menu.paste".localized) { fileManager.pasteClipboard() }
            .disabled(!fileManager.canPaste)
        Divider()
        Button("menu.copyPath".localized) {
            let sel = displayFiles.filter { selectedIDs.contains($0.id) }
            if sel.count > 1 { fileManager.copyPaths(sel) } else { fileManager.copyPath(item) }
        }
        .disabled(!item.url.isFileURL)
        Button("menu.terminal".localized) { fileManager.openTerminal(at: item) }
            .disabled(!item.url.isFileURL)
        if !item.url.isFileURL {
            Divider()
            Button("menu.link.renameTitle".localized) {
                renameLinkTitle(item)
            }
            Button("menu.link.changeIcon".localized) {
                changeLinkIcon(item)
            }
        }
        Button("menu.moveToTrash".localized, role: .destructive) {
            let sel = displayFiles.filter { selectedIDs.contains($0.id) }
            if sel.count > 1 { fileManager.moveToTrash(sel) } else { fileManager.moveToTrash(item) }
        }
        Button("menu.rename".localized) { fileManager.rename(item) }
        Button("menu.properties".localized) { propertiesItem = item }
        Divider()
        if item.url.pathExtension.lowercased() == "app" {
            Menu("menu.addToTag".localized) {
                ForEach(AppPreferences.shared.tagList, id: \.self) { tg in
                    Button(tg) {
                        AppPreferences.shared.addApp(item.url.path, toTag: tg)
                    }
                }
                Button("menu.newTag".localized) {
                    createTagPrompt()
                }
            }
            Menu("menu.removeFromTag".localized) {
                let tags = AppPreferences.shared.tags(for: item.url.path)
                if tags.isEmpty {
                    Text("menu.noTags".localized)
                } else {
                    ForEach(tags, id: \.self) { tg in
                        Button(tg) {
                            AppPreferences.shared.removeApp(item.url.path, fromTag: tg)
                        }
                    }
                    Divider()
                    Button("menu.clearTags".localized) {
                        AppPreferences.shared.clearTags(for: item.url.path)
                    }
                }
            }
        }
        if !item.isDirectory && item.url.isFileURL {
            OpenWithMenu(fileManager: fileManager, item: item)
        } else {
            Button("menu.openWith".localized) { }
                .disabled(true)
        }
        Button("menu.compress".localized) { fileManager.compress(item) }
            .disabled(!item.url.isFileURL)
        Button("menu.compressTo".localized) { fileManager.compressAs(item) }
            .disabled(!item.url.isFileURL)
        Button("menu.decompress".localized) {
            let sel = displayFiles.filter { selectedIDs.contains($0.id) }
            if selectedIDs.contains(item.id) && sel.count > 1 {
                fileManager.decompress(sel)
            } else {
                fileManager.decompress(item)
            }
        }
            .disabled(!ArchiveManager.shared.isSupportedArchive(item.url))
        Button("menu.decompressTo".localized) {
            let sel = displayFiles.filter { selectedIDs.contains($0.id) }
            if selectedIDs.contains(item.id) && sel.count > 1 {
                fileManager.decompressTo(sel)
            } else {
                fileManager.decompressTo(item)
            }
        }
            .disabled(!ArchiveManager.shared.isSupportedArchive(item.url))
    }
}
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = self.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
