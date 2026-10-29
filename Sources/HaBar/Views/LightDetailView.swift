import SwiftUI

public struct LightDetailView: View {
    @ObservedObject public var store: HomeAssistantStore
    public let deviceId: String

    public init(store: HomeAssistantStore, deviceId: String) {
        self.store = store
        self.deviceId = deviceId
    }

    private var currentDevice: HADeviceItem {
        store.devices.first(where: { $0.id == deviceId }) ?? HADeviceItem.defaultMockupDevices[0]
    }

    public var body: some View {
        let item = currentDevice
        let accent = item.accentColor

        VStack(alignment: .leading, spacing: 14) {
            NavigationBackButton {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    store.selectedDeviceForDetail = nil
                }
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(item.room.name) • \(item.isOn ? "Ligado" : "Desligado")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.toggleDevice(item.id)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(item.isOn ? accent.opacity(0.28) : Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(item.isOn ? accent.opacity(0.65) : Color.white.opacity(0.15), lineWidth: 1.2)
                            )
                            .shadow(color: item.isOn ? accent.opacity(0.55) : .clear, radius: 10)

                        Image(systemName: "power")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(item.isOn ? accent : .white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
            }

            if item.supportsBrightness {
                TactileSlider(
                    percentage: Binding(
                        get: { item.isOn ? item.brightnessPct : 0 },
                        set: { store.setBrightness(for: item.id, percentage: $0) }
                    ),
                    fillColor: item.isOn ? accent : Color.white.opacity(0.35),
                    height: 36,
                    showPercentageInside: true,
                    onChanged: { store.setBrightness(for: item.id, percentage: $0) }
                )
                .padding(.vertical, 2)
            }

            if item.supportsColor {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cores & Temperatura")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))

                    ColorSpectrumView(
                        activePresetId: item.activePresetId,
                        currentRGB: item.rgbColor,
                        onSelectPreset: { store.applyColorPreset($0, to: item.id) },
                        onSelectCustomRGB: { store.setCustomRGB($0, for: item.id) }
                    )
                }
            }

            if !item.availableEffects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Efeitos")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))

                    HStack(spacing: 8) {
                        ForEach(item.availableEffects, id: \.self) { effect in
                            let isSelected = (item.activeEffect == effect)
                            Button {
                                store.setEffect(effect, for: item.id)
                            } label: {
                                Text(effect)
                                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(.white.opacity(isSelected ? 0.98 : 0.72))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? accent.opacity(0.26) : Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? accent.opacity(0.75) : Color.white.opacity(0.12), lineWidth: 1.1)
                                    )
                                    .shadow(color: isSelected ? accent.opacity(0.35) : .clear, radius: 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.10))
                .padding(.top, 2)

            HStack {
                Spacer()
                Text("Entidade: \(item.id)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.48))
                Spacer()
            }
        }
    }
}
