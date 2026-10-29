import SwiftUI
import AppKit

@main
public struct HaBarApp: App {
    @StateObject private var store = HomeAssistantStore()

    public init() {}

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
