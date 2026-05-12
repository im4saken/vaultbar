import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var repository: KeyRepository
    var onClose: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var draftLabel = ""
    @State private var draftSecret = ""
    @State private var showingDeleteConfirmation = false
    @State private var isShowingSecret = false
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

                Spacer()
            }
            .padding(.leading, 76)
            .padding(.trailing, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            HStack(spacing: 0) {
                keyList
                    .frame(width: 190)

                Divider()

                editor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            clipboardSettings
                .padding(16)
        }
        .frame(width: 520, height: 420)
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
        .frame(width: 500)
    }

    @MainActor
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            selectedFileURL = url
            Task { await loadPreview() }
        }
    }

    @MainActor
    private func loadPreview() async {
        do {
            let content = try String(contentsOf: selectedFileURL!, encoding: .utf8)
            importPreview = content.prefix(500).description
        } catch {
            importPreview = "Error reading file: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func importFile() async {
        guard let url = selectedFileURL else { return }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let (successCount, errors) = await repository.batchImport(textContent: content)

            var message = ""
            if successCount > 0 {
                message += "Imported \(successCount) key\(successCount == 1 ? "" : "s")."
            }
            if !errors.isEmpty {
                message += "\n\n\(errors.count) error(s):\n" + errors.joined(separator: "\n")
            }

            batchResultMessage = message
            showingBatchResult = true
            selectedFileURL = nil
            importPreview = ""
        } catch {
            batchResultMessage = "Error: \(error.localizedDescription)"
            showingBatchResult = true
        }
    }

    private var keyList: some View {
        List(repository.items, id: \.id) { item in
            Button {
                selectedID = item.id
                loadDraft(from: item)
            } label: {
                Text(item.label)
                    .lineLimit(1)
                    .foregroundStyle(selectedID == item.id ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            if selectedMetadata != nil {
                Text("Edit Key")
                    .font(.headline)

                TextField("Label", text: $draftLabel)
                    .textFieldStyle(.roundedBorder)

                if isShowingSecret {
                    TextField("Key", text: $draftSecret)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(!isUnlocked)
                } else {
                    SecureField(isUnlocked ? "Key" : "Locked", text: $draftSecret)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(!isUnlocked)
                }

                HStack {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .frame(width: 90)

                    Spacer()

                    Button {
                        isShowingSecret.toggle()
                    } label: {
                        Label(isShowingSecret ? "Hide" : "Show", systemImage: isShowingSecret ? "eye.slash" : "eye")
                    }
                    .frame(width: 82)
                    .disabled(!isUnlocked)

                    Button {
                        saveSelected()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .frame(width: 82)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isUnlocked)
                }
            } else {
                ContentUnavailableView(
                    "No Keys",
                    systemImage: "key",
                    description: Text("Add a key from the search bar.")
                )
            }
        }
        .padding(20)
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
        isShowingSecret = false
    }

    private func saveSelected() {
        guard let selectedID else { return }
        Task {
            if await repository.update(id: selectedID, label: draftLabel, secret: draftSecret) {
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
            draftSecret = ""
            isShowingSecret = false
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
