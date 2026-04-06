import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var useProxy: Bool
    @State private var host: String
    @State private var portText: String

    init() {
        let s = ProxySettings.shared
        _useProxy  = State(initialValue: s.useProxy)
        _host      = State(initialValue: s.host)
        _portText  = State(initialValue: "\(s.port)")
    }

    private var portValid: Bool {
        guard let n = Int(portText) else { return false }
        return (1...65535).contains(n)
    }

    private var saveDisabled: Bool {
        useProxy && (host.trimmingCharacters(in: .whitespaces).isEmpty || !portValid)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Settings")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Proxy toggle
                Toggle("Use HTTP Proxy", isOn: $useProxy)
                    .toggleStyle(.switch)

                // Host + Port (only when proxy is on)
                if useProxy {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Host")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. 127.0.0.1", text: $host)
                            .textFieldStyle(.roundedBorder)

                        Text("Port")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("1080", text: $portText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        if !portText.isEmpty && !portValid {
                            Text("Port must be 1 – 65535")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.15), value: useProxy)

            Divider()

            // Footer buttons
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    ProxySettings.shared.apply(
                        useProxy: useProxy,
                        host: host.trimmingCharacters(in: .whitespaces),
                        port: Int(portText) ?? 1080
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(saveDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
    }
}
