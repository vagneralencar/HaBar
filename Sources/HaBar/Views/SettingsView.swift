import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject public var store: HomeAssistantStore
    @State private var urlInput: String = ""
    @State private var tokenInput: String = ""
    @State private var showPlainToken: Bool = false
    @State private var savedBannerVisible: Bool = false

    public init(store: HomeAssistantStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                NavigationBackButton {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        store.isShowingSettings = false
                    }
                }

                Spacer()

                Text("Configurações — HaBar")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("URL do Servidor Home Assistant")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))

                TextField("http://homeassistant.local:8123", text: $urlInput)
                    .glassInputField()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Long-Lived Access Token")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))

                    Spacer()

                    Button {
                        if let pasted = NSPasteboard.general.string(forType: .string) {
                            tokenInput = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Colar Token")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.amberAccent)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showPlainToken.toggle()
                    } label: {
                        Image(systemName: showPlainToken ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }

                if showPlainToken {
                    TextField("Cole seu token do Home Assistant...", text: $tokenInput)
                        .glassInputField()
                } else {
                    SecureField("Cole seu token do Home Assistant...", text: $tokenInput)
                        .glassInputField()
                }

                Text("Cenas sincronizadas: \(store.scenes.count)  •  Cômodos: \(max(0, store.rooms.count - 1))  •  Dispositivos: \(store.devices.count)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(AppTheme.greenOnline.opacity(0.9))
            }

            Button {
                store.saveSettingsAndConnect(url: urlInput, token: tokenInput)
                withAnimation { savedBannerVisible = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    savedBannerVisible = false
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    Text("Salvar & Sincronizar Cenas e Cômodos")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 12.5))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.amberAccent)
                )
            }
            .buttonStyle(.plain)

            if savedBannerVisible {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.greenOnline)
                    Text("Sincronizado com sucesso com o Home Assistant!")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            Divider()
                .background(Color.white.opacity(0.10))

            HStack {
                Button {
                    store.openHomeAssistantInBrowser()
                } label: {
                    Label("Abrir Web UI (:8123)", systemImage: "safari")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Encerrar HaBar", systemImage: "power")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.dangerRed)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            urlInput = store.serverURLString
            tokenInput = store.accessToken
        }
    }
}
