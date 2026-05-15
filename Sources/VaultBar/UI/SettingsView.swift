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
    @State private var showingBatchImport = false
    @State private var selectedFileURL: URL?
    @State private var importPreview = ""
    @State private var showingBatchResult = false
    @State private var batchResultMessage = ""

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
                Text("Settings")
                    .font(.title3.weight(.semibold))

                Button(action: { showingBatchImport = true }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Batch import keys")
                .hidden()

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
        .confirmationDialog("Delete API Key?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the Keychain item and encrypted metadata.")
        }
        .sheet(isPresented: $showingBatchImport) {
            batchImportSheet
        }
        .alert("Batch Import Result", isPresented: $showingBatchResult) {
            Button("OK") { }
        } message: {
            Text(batchResultMessage)
        }
    }

    private var batchImportSheet: some View {
        VStack(spacing: 16) {
            Text("Batch Import")
                .font(.title3.weight(.semibold))

            Text("Import a plain text file (.csv or .md) with one key per line in the format: label,api_key")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Choose File…") {
                selectFile()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let selectedFileURL {
                Text(selectedFileURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !importPreview.isEmpty {
                ScrollView {
                    Text(importPreview)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    selectedFileURL = nil
                    importPreview = ""
                    dismiss()
                }
                Button("Import") {
                    Task { await importFile() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedFileURL == nil || importPreview.isEmpty)
            }
        }
        .padding(24)
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText]
        panel.begin { result in
            if result == .OK, let url = panel.url {
                selectedFileURL = url
                Task { await loadPreview(from: url) }
            }
        }
    }

    private func loadPreview(from url: URL) async {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            importPreview = String(content.prefix(500))
        } catch {
            importPreview = "Failed to read file: \(error.localizedDescription)"
        }
    }

    private func importFile() async {
        guard let url = selectedFileURL else { return }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let result = await repository.batchImport(textContent: content)
            batchResultMessage = "成功导入 \(result.successCount) 个密钥"
            if !result.errorMessages.isEmpty {
                batchResultMessage += "\n\n错误:\n" + result.errorMessages.joined(separator: "\n")
            }
            showingBatchResult = true
        } catch {
            batchResultMessage = "导入失败: \(error.localizedDescription)"
            showingBatchResult = true
        }
    }

    private var keyList: some View {
        VStack(spacing: 0) {
            Text("API Keys")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
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
                    .padding(16)

                    Divider()

                    HStack {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            saveSelected()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isUnlocked)
                    }
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
            }
        }
    }

    private func deleteSelected() {
        guard let selectedID else { return }
        Task {
            if await repository.delete(id: selectedID) {
                unlockedSecrets[selectedID] = nil
                self.selectedID = repository.items.sorted { $0.updatedAt > $1.updatedAt }.first?.id
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
