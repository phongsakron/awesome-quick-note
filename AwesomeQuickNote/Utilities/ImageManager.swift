import AppKit
import Foundation

@MainActor
final class ImageManager {
    private let vaultManager: VaultManager

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    func saveImage(_ image: NSImage) -> String? {
        guard let attachmentsURL = vaultManager.attachmentsURL else { return nil }

        let filename = "img-\(UUID().uuidString.prefix(8)).png"
        let fileURL = attachmentsURL.appendingPathComponent(filename)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: fileURL)
            return "![image](attachments/\(filename))"
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    func saveImageFromPasteboard() -> String? {
        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        return saveImage(image)
    }

    func saveImageFromDrop(providers: [NSItemProvider], completion: @escaping (String?) -> Void) {
        guard let provider = providers.first else {
            completion(nil)
            return
        }

        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { [weak self] image, error in
                Task { @MainActor in
                    if let image = image as? NSImage {
                        completion(self?.saveImage(image))
                    } else {
                        completion(nil)
                    }
                }
            }
        } else {
            completion(nil)
        }
    }
}
