import SwiftUI

struct AddKeyView: View {
    @ObservedObject var repository: KeyRepository
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    @State private var draft = NewAPIKey(label: "", secret: "", website: "", notes: "")
    @FocusState private var focusedField: Field?
    @State private var showSavedToast = false

    private enum Field {
        case label
        case secret
        case website
        case notes
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .frame(width: 84, height: 84)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.black.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 10)

                VStack(spacing: 0) {
                    formRow(title: "标题") {
                        TextField("标题", text: $draft.label)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .label)
                    }

                    Divider().opacity(0.5)

                    formRow(title: "API/Token") {
                        SecureField("API/Token", text: $draft.secret)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .secret)
                    }

                    Divider().opacity(0.5)

                    formRow(title: "网站") {
                        TextField("example.com", text: $draft.website)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .website)
                    }

                    Divider().opacity(0.5)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("备注")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.82))
                                .frame(width: 84, alignment: .leading)

                            TextEditor(text: $draft.notes)
                                .font(.system(size: 15))
                                .scrollContentBackground(.hidden)
                                .focused($focusedField, equals: .notes)
                                .frame(minHeight: 60, maxHeight: 84)
                                .padding(.vertical, 2)
                                .background(Color.clear)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.08))
                )

                Spacer(minLength: 6)

                HStack {
                    Spacer()
                    Button("取消") {
                        close()
                    }
                    .buttonStyle(.bordered)

                    Button("保存") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
                }
            }
            .padding(24)
        }
        .frame(width: 380, height: 420, alignment: .topLeading)
        .onAppear {
            focusedField = .label
        }
        .onSubmit {
            if draft.isValid {
                save()
            }
        }
        .overlay {
            savedToast
        }
    }

    private var savedToast: some View {
        Group {
            if showSavedToast {
                Text("项目已储存")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.9))
                    )
                    .padding(.bottom, 24)
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

    private func save() {
        Task {
            if await repository.add(draft) {
                draft = NewAPIKey(label: "", secret: "", website: "", notes: "")
                showSavedToast = true
                close()
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    showSavedToast = false
                }
            }
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
