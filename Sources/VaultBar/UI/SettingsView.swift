import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var repository: KeyRepository
    var onClose: () -> Void = {}
    var aboutAction: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var draftLabel = ""
    @State private var draftSecret = ""
    @State private var draftWebsite = ""
    @State private var draftNotes = ""
    @State private var showingDeleteConfirmation = false
    @State private var unlockedSecrets: [UUID: String] = [:]
    @State private var statusToast: String?

    private let timeoutOptions = [
        TimeoutOption(label: "Never", seconds: 0),
        TimeoutOption(label: "15 sec", seconds: 15),
        TimeoutOption(label: "30 sec", seconds: 30),
        TimeoutOption(label: "60 sec", seconds: 60),
        TimeoutOption(label: "2 min", seconds: 120),
        TimeoutOption(label: "5 min", seconds: 300)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("设置")
                    .font(.title3.weight(.semibold))

                Button(action: { importTapped() }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("批量导入")

                Button(action: { startExport() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("导出为 CSV（含明文密钥）")
                .disabled(repository.items.isEmpty)

                unlockButton

                if let aboutAction {
                    Button(action: aboutAction) {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("About")
                }

                Spacer()
            }
            .padding(.leading, 76)
            .padding(.trailing, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            // Key list + Editor
            HStack(spacing: 0) {
                keyList
                    .frame(width: 190)

                Divider()

                editor
            }

            Divider()

            // Clipboard settings footer
            clipboardSettings
                .padding(14)
        }
        .frame(width: 520, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            statusToastView
        }
        .onAppear {
            selectInitialKey()
        }
        .onChange(of: repository.items) { _, _ in
            guard selectedID == nil || repository.items.contains(where: { $0.id == selectedID }) else {
                selectInitialKey()
                return
            }
            if let selectedMetadata {
                loadDraft(from: selectedMetadata)
            }
        }
        .confirmationDialog("删除这个 API Key？", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                deleteSelected()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将同时移除 Keychain 条目和加密元数据。")
        }
    }

    private var statusToastView: some View {
        Group {
            if let statusToast {
                Text(statusToast)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.9))
                    )
                    .padding(.bottom, 70)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: statusToast)
    }

    private func showToast(_ message: String) {
        statusToast = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusToast == message {
                statusToast = nil
            }
        }
    }

    private func importTapped() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "批量导入"
        alert.informativeText = """
        把 CSV 内容粘贴到下方文本框，然后点「导入」。

        支持格式：
        • 4 列 label,api_key,website,notes（推荐，导出也用此格式）
        • 2 列 label,api_key（兼容旧版）
        • # 或 // 开头的行视为注释；表头行会被跳过
        • 同名条目作为新条目添加，不会去重

        内容含明文 API Key，导入后请妥善清理来源。
        """

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 200))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 460, height: 200))
        textView.isEditable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.autoresizingMask = [.width]
        scroll.documentView = textView
        alert.accessoryView = scroll

        alert.addButton(withTitle: "导入")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = textView
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let text = textView.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showResultAlert(title: "批量导入结果", message: "没有可导入的内容。")
            return
        }
        Task {
            let result = await repository.batchImport(textContent: text)
            var message = "成功导入 \(result.successCount) 个密钥"
            if !result.errorMessages.isEmpty {
                message += "\n\n错误:\n" + result.errorMessages.joined(separator: "\n")
            }
            showResultAlert(title: "批量导入结果", message: message)
        }
    }

    private func startExport() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "导出包含明文密钥"
        alert.informativeText = """
        • 导出的 CSV 包含未加密的 API Key，任何能读到这个文件的人都能看到所有密钥
        • 文件会写入「下载」文件夹（~/Downloads）
        • 不要放到 iCloud / Dropbox 等会自动同步的位置；不要放进 Git 仓库、聊天工具或公开存储
        • 使用完毕后请妥善删除该文件

        继续后会通过 Touch ID 确认身份。
        """
        alert.addButton(withTitle: "继续导出")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await performExport() }
    }

    private func performExport() async {
        var secrets = unlockedSecrets
        if secrets.isEmpty {
            secrets = await repository.unlockSecretsForSettings()
            guard !secrets.isEmpty else { return }
            unlockedSecrets = secrets
        }
        let csv = repository.exportAllAsCSV(secrets: secrets)

        guard let downloads = FileManager.default.urls(
            for: .downloadsDirectory, in: .userDomainMask
        ).first else {
            showResultAlert(title: "导出失败", message: "找不到「下载」文件夹。")
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = downloads.appendingPathComponent(
            "vaultbar-export-\(formatter.string(from: Date())).csv"
        )
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            showExportSuccessAlert(url: url)
        } catch {
            showResultAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func showResultAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showExportSuccessAlert(url: URL) {
        let alert = NSAlert()
        alert.messageText = "导出成功"
        alert.informativeText = "已保存到：\n\(url.path)\n\n这是明文文件，请妥善保管并在用完后删除。"
        alert.addButton(withTitle: "在 Finder 中显示")
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private var keyList: some View {
        VStack(spacing: 0) {
            Text("API Keys")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
                .padding(.trailing, 16)
                .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(repository.items.sorted { $0.updatedAt > $1.updatedAt }) { item in
                        keyRow(item)
                    }

                    if repository.items.isEmpty {
                        ContentUnavailableView(
                            "No Keys",
                            systemImage: "key",
                            description: Text("Add a key from the search bar.")
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func keyRow(_ item: KeyMetadata) -> some View {
        Button {
            selectedID = item.id
            loadDraft(from: item)
        } label: {
            HStack(spacing: 0) {
                Image(systemName: "key")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .leading)

                Text(item.label)
                    .lineLimit(1)
                    .foregroundStyle(.primary.opacity(selectedID == item.id ? 1.0 : 0.7))

                Spacer(minLength: 0)
            }
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
        .background(selectedID == item.id ? Color.accentColor.opacity(0.12) : .clear)
    }

    private var editor: some View {
        Group {
            if selectedID != nil && repository.items.contains(where: { $0.id == selectedID }) {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        formRow(title: "标题") {
                            TextField("标题", text: $draftLabel)
                                .textFieldStyle(.plain)
                        }

                        Divider().opacity(0.5)

                        formRow(title: "API/Token") {
                            SecureField("API/Token", text: $draftSecret)
                                .textFieldStyle(.plain)
                        }

                        Divider().opacity(0.5)

                        formRow(title: "网站") {
                            TextField("example.com", text: $draftWebsite)
                                .textFieldStyle(.plain)
                        }

                        Divider().opacity(0.5)

                        formRow(title: "备注") {
                            TextEditor(text: $draftNotes)
                                .font(.system(size: 15))
                                .scrollContentBackground(.hidden)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 28)
                    .padding(.vertical, 16)

                    Divider()

                    HStack {
                        Spacer()

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)

                        Spacer().frame(width: 16)

                        Button {
                            saveSelected()
                        } label: {
                            Label("保存", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!isDirty || draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isUnlocked)

                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
            } else {
                ContentUnavailableView(
                    "No Keys",
                    systemImage: "key",
                    description: Text("Add a key from the search bar.")
                )
            }
        }
    }

    private func formRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.82))
                .frame(width: 84, alignment: .leading)

            content()
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 12)
    }

    private var unlockButton: some View {
        Button {
            toggleLockState()
        } label: {
            Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isUnlocked ? "Lock all keys" : "Unlock all keys")
    }

    private var clipboardSettings: some View {
        HStack(spacing: 12) {
            Image(systemName: "clipboard")
                .foregroundStyle(.secondary)

            Text("Clipboard cleared after:")
                .font(.subheadline.weight(.medium))

            Picker("", selection: $repository.clipboardClearSeconds) {
                ForEach(timeoutOptions) { option in
                    Text(option.label).tag(option.seconds)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)
        }
    }

    private var selectedMetadata: KeyMetadata? {
        guard let selectedID else { return nil }
        return repository.items.first { $0.id == selectedID }
    }

    private var isUnlocked: Bool {
        !unlockedSecrets.isEmpty || repository.items.isEmpty
    }

    private var isDirty: Bool {
        guard let meta = selectedMetadata else { return false }
        return draftLabel != meta.label
            || draftWebsite != meta.website
            || draftNotes != meta.notes
            || draftSecret != (unlockedSecrets[meta.id] ?? "")
    }

    private func selectInitialKey() {
        let first = repository.items.sorted { $0.updatedAt > $1.updatedAt }.first
        selectedID = first?.id
        if let first {
            loadDraft(from: first)
        }
    }

    private func loadDraft(from metadata: KeyMetadata) {
        draftLabel = metadata.label
        draftSecret = unlockedSecrets[metadata.id] ?? ""
        draftWebsite = metadata.website
        draftNotes = metadata.notes
    }

    private func saveSelected() {
        guard let selectedID else { return }
        Task {
            if await repository.update(id: selectedID, label: draftLabel, secret: draftSecret, website: draftWebsite, notes: draftNotes) {
                unlockedSecrets[selectedID] = draftSecret
                showToast("已保存")
            }
        }
    }

    private func deleteSelected() {
        guard let selectedID else { return }
        Task {
            if await repository.delete(id: selectedID) {
                unlockedSecrets[selectedID] = nil
                self.selectedID = repository.items.sorted { $0.updatedAt > $1.updatedAt }.first?.id
                showToast("已删除")
            }
        }
    }

    private func toggleLockState() {
        if isUnlocked {
            lockAllSecrets()
        } else {
            unlockAllSecrets()
        }
    }

    private func lockAllSecrets() {
        unlockedSecrets = [:]
        if let selectedMetadata {
            loadDraft(from: selectedMetadata)
        } else {
            draftLabel = ""
            draftSecret = ""
            draftWebsite = ""
            draftNotes = ""
        }
    }

    private func unlockAllSecrets() {
        Task {
            let secrets = await repository.unlockSecretsForSettings()
            guard !secrets.isEmpty || repository.items.isEmpty else { return }
            unlockedSecrets = secrets
            if let selectedMetadata {
                loadDraft(from: selectedMetadata)
            }
        }
    }
}

private struct TimeoutOption: Identifiable {
    let label: String
    let seconds: Int

    var id: Int { seconds }
}
