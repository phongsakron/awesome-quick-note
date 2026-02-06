import MarkdownUI
import SwiftUI

struct NotePreviewView: View {
    let content: String
    let vaultURL: URL?
    var onToggleCheckbox: ((Int) -> Void)?

    var body: some View {
        ScrollView {
            Markdown(content)
                .markdownTheme(.monokai)
                .markdownImageProvider(LocalImageProvider(vaultURL: vaultURL))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }
}

struct LocalImageProvider: ImageProvider {
    let vaultURL: URL?

    func makeImage(url: URL?) -> some View {
        if let url, let resolvedURL = resolveURL(url) {
            AsyncImage(url: resolvedURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 400)
                        .clipShape(.rect(cornerRadius: 4))
                case .failure:
                    Label("Failed to load image", systemImage: "photo.badge.exclamationmark")
                        .foregroundStyle(Monokai.comment)
                default:
                    ProgressView()
                        .frame(width: 100, height: 60)
                }
            }
        } else {
            Label("Image not found", systemImage: "photo")
                .foregroundStyle(Monokai.comment)
        }
    }

    private func resolveURL(_ url: URL) -> URL? {
        if url.scheme == nil || url.scheme == "file" {
            // Relative path — resolve against vault URL
            guard let vaultURL else { return nil }
            let relativePath = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
            let resolved = vaultURL.appendingPathComponent(relativePath)
            return FileManager.default.fileExists(atPath: resolved.path) ? resolved : nil
        }
        return url
    }
}
