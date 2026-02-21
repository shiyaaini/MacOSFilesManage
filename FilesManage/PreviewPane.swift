import SwiftUI
import AppKit
import QuickLookThumbnailing
import PDFKit

struct PreviewPane: View {
    @ObservedObject var fileManager: FileManager_Custom
    let selectedItem: FileItem?
    @State private var previewURL: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let item = selectedItem {
                Text(item.name).font(.headline)
                Divider()
                if item.isDirectory {
                    folderInfo(item)
                } else if item.url.isImageFile {
                    if let url = previewURL {
                        imagePreview(url)
                    } else {
                        ProgressView().scaleEffect(0.5)
                    }
                    fileInfo(item)
                } else if item.url.isPDFFile {
                    if let url = previewURL {
                        pdfPreview(url)
                    } else {
                        ProgressView().scaleEffect(0.5)
                    }
                    fileInfo(item)
                } else if item.url.isTextFile {
                    if let url = previewURL {
                        textPreview(url)
                    } else {
                        ProgressView().scaleEffect(0.5)
                    }
                    fileInfo(item)
                } else {
                    iconPreview(item)
                }
            } else {
                Text("preview.selectFile".localized)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .frame(maxHeight: .infinity)
        .clipped()
        .onChange(of: selectedItem) { _, newItem in
            loadPreview(newItem)
        }
        .onAppear {
            loadPreview(selectedItem)
        }
    }
    
    private func loadPreview(_ item: FileItem?) {
        previewURL = nil
        guard let item = item, !item.isDirectory else { return }
        
        if item.isVirtual {
            fileManager.prepareItemForPreview(item) { url in
                self.previewURL = url
            }
        } else {
            self.previewURL = item.url
        }
    }
    
    private func folderInfo(_ item: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(nsImage: item.icon).resizable().frame(width: 64, height: 64)
            Text("preview.folder".localized).font(.subheadline)
            Text(item.formattedDate).font(.caption).foregroundColor(.secondary)
        }
    }
    
    private func imagePreview(_ url: URL) -> some View {
        GeometryReader { geo in
            AsyncImagePreview(url: url, width: geo.size.width, height: geo.size.height)
        }
    }
    
    private func pdfPreview(_ url: URL) -> some View {
        PDFKitView(url: url)
    }
    
    private func textPreview(_ url: URL) -> some View {
        AsyncTextPreview(url: url)
    }
    
    private func fileInfo(_ item: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text("file.size".localized + ":")
                Text(item.formattedSize).foregroundColor(.secondary)
            }
            HStack {
                Text("file.modifiedDate".localized + ":")
                Text(item.formattedDate).foregroundColor(.secondary)
            }
            HStack {
                Text("file.path".localized + ":")
                Text(item.url.path).foregroundColor(.secondary)
            }
            HStack {
                Text("file.type".localized + ":")
                Text(item.isDirectory ? "preview.folder".localized : item.url.pathExtension.isEmpty ? "file.file".localized : item.url.pathExtension.uppercased()).foregroundColor(.secondary)
            }
        }
        .font(.caption)
    }
    
    private func iconPreview(_ item: FileItem) -> some View {
        VStack(spacing: 8) {
            Image(nsImage: item.icon).resizable().frame(width: 64, height: 64)
            Text(item.formattedSize).font(.caption).foregroundColor(.secondary)
            Text(item.formattedDate).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct AsyncImagePreview: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat
    @State private var image: NSImage?
    @State private var loadToken = UUID()
    
    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
            } else {
                Text("file.loading".localized).foregroundColor(.secondary)
            }
        }
        .onAppear { load() }
        .onChange(of: url) { _, _ in load() }
    }
    
    private func load() {
        let token = UUID()
        loadToken = token
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async {
                if self.loadToken != token { return }
                image = img
            }
        }
    }
}

private struct AsyncTextPreview: View {
    let url: URL
    @State private var text: String?
    @State private var loadToken = UUID()
    
    var body: some View {
        Group {
            if let str = text {
                ScrollView {
                    Text(str)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("file.loading".localized).foregroundColor(.secondary)
            }
        }
        .onAppear { load() }
        .onChange(of: url) { _, _ in load() }
    }
    
    private func load() {
        let token = UUID()
        loadToken = token
        DispatchQueue.global(qos: .userInitiated).async {
            let data = try? Data(contentsOf: url)
            let str = data.flatMap { String(data: $0.prefix(200_000), encoding: .utf8) }
            DispatchQueue.main.async {
                if self.loadToken != token { return }
                text = str
                if str != nil {
                    print("Preview text loaded:", url.lastPathComponent)
                } else {
                    print("Preview text failed:", url.lastPathComponent)
                }
            }
        }
    }
}
private struct PDFKitView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.document = nil
        loadPDF(into: v)
        return v
    }
    func updateNSView(_ nsView: PDFView, context: Context) {
        loadPDF(into: nsView)
    }
    private func loadPDF(into view: PDFView) {
        view.document = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let doc = PDFDocument(url: url)
            DispatchQueue.main.async {
                view.document = doc
                if doc != nil {
                    print("Preview PDF loaded:", url.lastPathComponent)
                } else {
                    print("Preview PDF failed:", url.lastPathComponent)
                }
            }
        }
    }
}
