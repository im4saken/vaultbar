import SwiftUI

struct CapsuleSearchView: View {
    @ObservedObject var repository: KeyRepository
    let onAddKey: () -> Void
    @FocusState private var searchFieldFocused: Bool
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    onAddKey()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .help("Add Key")
                .keyboardShortcut("n", modifiers: .command)

                FocusedSearchField(
                    text: $repository.searchText,
                    placeholder: "Search API Keys..."
                ) {
                    handleEnter()
                }
                .focused($searchFieldFocused)
                .frame(height: 30)
                .onChange(of: repository.searchText) { _, _ in
                    repository.resetSelectionToTop()
                }

                Button {
                    handleCopyButton()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .help("Copy")

                Button {
                    NotificationCenter.default.post(name: .vaultBarOpenSettings, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(
                VisualEffectView(material: .hudWindow)
                    .clipShape(Capsule())
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

            ResultsDropdown(
                results: Array(repository.searchResults.prefix(5)),
                selectedID: repository.selectedID,
                onSelect: { result in
                    selectAndFill(result)
                },
                onCopy: { result in
                    selectAndFill(result)
                }
            )
            .opacity(repository.searchResults.isEmpty ? 0 : 1)

            copiedToast
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(width: 454, alignment: .top)
        .onAppear {
            searchFieldFocused = true
        }
        .alert("VaultBar", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                repository.errorMessage = nil
            }
        } message: {
            Text(repository.errorMessage ?? "")
        }
    }

    private var copiedToast: some View {
        Group {
            if showCopiedToast && selectedResultForToast() != nil {
                Text("API/Token已复制")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.85))
                    )
                    .padding(.top, 4)
            }
        }
    }

    private func selectedResultForToast() -> KeyMetadata? {
        guard let id = repository.selectedID else { return nil }
        return repository.items.first { $0.id == id }
    }

    private func selectAndFill(_ result: KeyMetadata) {
        repository.selectedID = result.id
        repository.searchText = result.label
        copyKey(result)
    }

    private func handleEnter() {
        if let result = repository.selectedOrTopResult {
            selectAndFill(result)
        }
    }

    private func handleCopyButton() {
        if let result = repository.selectedOrTopResult {
            selectAndFill(result)
        } else if !repository.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NSSound.beep()
        }
    }

    private func copyKey(_ metadata: KeyMetadata) {
        do {
            let secret = try repository.readSecret(id: metadata.id)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(secret, forType: .string)
            repository.scheduleClipboardClear(changeCount: NSPasteboard.general.changeCount)

            showCopiedToast = true
            Task {
                try? await Task.sleep(for: .seconds(5))
                showCopiedToast = false
            }
        } catch {
            repository.errorMessage = error.localizedDescription
            NSSound.beep()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { repository.errorMessage != nil },
            set: { if !$0 { repository.errorMessage = nil } }
        )
    }
}

private struct ResultsDropdown: View {
    let results: [KeyMetadata]
    let selectedID: UUID?
    let onSelect: (KeyMetadata) -> Void
    let onCopy: (KeyMetadata) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(results) { result in
                Button {
                    onSelect(result)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "key")
                            .foregroundStyle(.secondary)
                        Text(result.label)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        onCopy(result)
                    }
                )
                .font(.system(size: 12, weight: result.id == selectedID ? .semibold : .regular))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(result.id == selectedID ? Color.accentColor.opacity(0.16) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            VisualEffectView(material: .popover)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}
