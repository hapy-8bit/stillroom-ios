import SwiftUI

/// This page owns form values and events. Credentials and requests stay in the
/// coordinator; the display component never opens a network connection itself.
struct OneTapeSourcesView: View {
    let connection: NavidromeConnection?
    let albumCount: Int
    let trackCount: Int
    let isLoading: Bool
    let isDisconnecting: Bool
    let progressText: String
    let message: String?
    let onConnect: (String, String, String) -> Void
    let onRefresh: () -> Void
    let onDisconnect: () -> Void
    let onCancel: () -> Void
    let onLocal: () -> Void
    let onOpenLibrary: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: onLocal) {
                        sourceRow("本地音乐", subtitle: "从“文件”选择音乐", icon: "folder")
                    }
                    .accessibilityIdentifier("source.local")
                    .disabled(isLoading)
                    NavigationLink {
                        OneTapeServerForm(connection: connection, albumCount: albumCount,
                            trackCount: trackCount, isLoading: isLoading, isDisconnecting: isDisconnecting, progressText: progressText,
                            message: message, onConnect: onConnect, onRefresh: onRefresh,
                            onDisconnect: onDisconnect, onCancel: onCancel, onOpenLibrary: onOpenLibrary)
                    } label: {
                        sourceRow("Navidrome", subtitle: connection?.baseURL.host ?? "连接你的音乐服务器",
                                  icon: "server.rack")
                    }
                    .accessibilityIdentifier("source.navidrome")
                } footer: {
                    Text("你的音乐，装进一盘磁带。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.065))
            .navigationTitle("添加音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.disabled(isLoading)
                        .accessibilityIdentifier("sources.close")
                }
            }
        }
        .interactiveDismissDisabled(isLoading)
        .preferredColorScheme(.dark)
    }

    private func sourceRow(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 24)).frame(width: 32)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).foregroundStyle(.primary)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(.vertical, 8)
    }
}

private struct OneTapeServerForm: View {
    let connection: NavidromeConnection?
    let albumCount: Int
    let trackCount: Int
    let isLoading: Bool
    let isDisconnecting: Bool
    let progressText: String
    let message: String?
    let onConnect: (String, String, String) -> Void
    let onRefresh: () -> Void
    let onDisconnect: () -> Void
    let onCancel: () -> Void
    let onOpenLibrary: () -> Void
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmingDisconnect = false
    @FocusState private var field: Field?
    private enum Field { case address, username, password }

    var body: some View {
        Form {
            // Keep progress and failures above the saved account. A connected
            // account adds several rows and would otherwise hide them below
            // the keyboard or the medium-height sheet's visible viewport.
            if isLoading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(progressText.isEmpty ? "正在读取音乐库…" : progressText)
                            .accessibilityIdentifier("navidrome.progress")
                    }
                    if !isDisconnecting {
                        Button("取消读取", role: .cancel, action: onCancel)
                            .accessibilityIdentifier("navidrome.cancel")
                    }
                }
            }
            if let message {
                Section {
                    Text(message).foregroundStyle(.orange)
                        .accessibilityIdentifier("navidrome.notice")
                }
            }
            if let connection {
                Section("已连接") {
                    Label(connection.baseURL.host ?? "Navidrome", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(albumCount) 张专辑 · \(trackCount) 首音乐")
                        .accessibilityIdentifier("navidrome.catalogSummary")
                    Button("查看音乐库", action: onOpenLibrary)
                        .disabled(isLoading)
                        .accessibilityIdentifier("navidrome.openLibrary")
                    Button("刷新音乐库", action: onRefresh).disabled(isLoading)
                        .accessibilityIdentifier("navidrome.refresh")
                    Button("断开此设备的连接", role: .destructive) { confirmingDisconnect = true }
                        .disabled(isLoading)
                        .accessibilityIdentifier("navidrome.disconnect")
                }
            }
            Section {
                TextField("https://music.example.com", text: $address)
                    .keyboardType(.URL).textContentType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($field, equals: .address)
                    .accessibilityLabel("服务器地址")
                    .accessibilityIdentifier("navidrome.address")
                TextField("用户名", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($field, equals: .username)
                    .accessibilityIdentifier("navidrome.username")
                SecureField("密码", text: $password)
                    .textContentType(.password).focused($field, equals: .password)
                    .submitLabel(.done)
                    .onSubmit { field = nil }
                    .accessibilityIdentifier("navidrome.password")
                Button("连接并读取音乐库") {
                    field = nil
                    onConnect(address, username, password)
                    password = ""
                }
                .disabled(isLoading || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || username.isEmpty || password.isEmpty)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("navidrome.connect")
            } header: {
                Text(connection == nil ? "音乐服务器" : "连接另一台服务器")
            } footer: {
                Text("音乐保留在你的服务器，通过网络播放。密码保存在此设备的钥匙串中。")
            }
            .disabled(isLoading)
        }
        .navigationTitle("Navidrome").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color(white: 0.065))
        .preferredColorScheme(.dark)
        .confirmationDialog("断开 Navidrome？", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
            Button("断开连接", role: .destructive, action: onDisconnect)
                .accessibilityIdentifier("navidrome.confirmDisconnect")
            Button("取消", role: .cancel) {}
        } message: {
            Text("只移除此设备上的服务器连接和远端目录；本地音乐保留，不会删除服务器音乐。")
        }
        .onAppear {
            address = connection?.baseURL.absoluteString ?? ""
            username = connection?.username ?? ""
        }
        .onDisappear { password = "" }
    }
}
