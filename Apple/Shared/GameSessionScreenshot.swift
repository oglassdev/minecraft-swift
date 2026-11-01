import Foundation

#if os(macOS)
    import AppKit
    import ScreenCaptureKit
#endif

extension GameSession {
    func captureScreenshot() {
        #if os(macOS)
            guard let window = NSApp.keyWindow, window.windowNumber > 0 else { return }
            let identifier = CGWindowID(window.windowNumber)
            let scale = window.backingScaleFactor
            let directory = gameDirectory.appendingPathComponent("screenshots", isDirectory: true)
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(
                        false, onScreenWindowsOnly: true)
                    guard let selected = content.windows.first(where: { $0.windowID == identifier }) else {
                        errorMessage = "Could not save screenshot: the game window is not visible."
                        return
                    }
                    let configuration = SCStreamConfiguration()
                    configuration.width = Int(selected.frame.width * scale)
                    configuration.height = Int(selected.frame.height * scale)
                    configuration.showsCursor = false
                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: SCContentFilter(desktopIndependentWindow: selected),
                        configuration: configuration)
                    let name = try await Task.detached { try Self.writePNG(image, in: directory) }.value
                    postChat("Saved screenshot as \(name)")
                } catch { errorMessage = "Could not save screenshot: \(error.localizedDescription)" }
            }
        #endif
    }

    #if os(macOS)
        private nonisolated static func writePNG(_ image: CGImage, in directory: URL) throws -> String {
            guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
            let stamp = formatter.string(from: Date())
            var name = stamp + ".png"
            var number = 2
            while FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
                name = "\(stamp)_\(number).png"
                number += 1
            }
            try data.write(to: directory.appendingPathComponent(name), options: .withoutOverwriting)
            return name
        }
    #endif
}
