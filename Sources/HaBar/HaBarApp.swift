import SwiftUI
import AppKit

@main
public struct HaBarApp: App {
    @StateObject private var store = HomeAssistantStore()

    public init() {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--export-screenshots"), idx + 1 < args.count {
            let outDir = args[idx + 1]
            MainActor.assumeIsolated {
                ScreenshotExporter.exportAll(to: outDir)
            }
            exit(0)
        }
    }

    public var body: some Scene {
        MenuBarExtra {
            MainPopoverView(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "house.fill")
                if store.activeLightsCount > 0 {
                    Text("\(store.activeLightsCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
enum ScreenshotExporter {
    static func exportAll(to directoryPath: String) {
        let dirURL = URL(fileURLWithPath: directoryPath)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let demoStore = HomeAssistantStore.makeScreenshotDemoStore()

        // 1. Render Main Dashboard Popover
        let dashboardFrame = PopoverScreenshotFrame {
            MainPopoverView(store: demoStore)
        }
        renderView(dashboardFrame, to: dirURL.appendingPathComponent("habar-dashboard.png"))

        // 2. Render Light Detail View (RGB / Kelvin / Effects)
        if let firstLight = demoStore.devices.first {
            demoStore.selectedDeviceForDetail = firstLight
        }
        let detailFrame = PopoverScreenshotFrame {
            MainPopoverView(store: demoStore)
        }
        renderView(detailFrame, to: dirURL.appendingPathComponent("habar-light-detail.png"))
    }

    private static func renderView<V: View>(_ view: V, to fileURL: URL) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: fileURL, options: .atomic)
    }
}

private struct PopoverScreenshotFrame<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.14),
                    Color(red: 0.14, green: 0.10, blue: 0.20),
                    Color(red: 0.06, green: 0.07, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            content
                .background(Color(red: 0.11, green: 0.11, blue: 0.13))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.65), radius: 28, x: 0, y: 16)
                .padding(28)
        }
        .fixedSize()
    }
}
