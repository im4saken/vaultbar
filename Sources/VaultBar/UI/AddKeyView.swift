import SwiftUI

struct AddKeyView: View {
    @ObservedObject var repository: KeyRepository
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NewAPIKey(label: "", secret: "")
    @FocusState private var focusedField: Field?

    private enum Field {
        case label
        case secret
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add API Key")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                TextField("Label", text: $draft.label)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .label)

                SecureField("Key", text: $draft.secret)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .secret)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
        }
        .padding(24)
        .onAppear {
            focusedField = .label
        }
    }

    private func save() {
        Task {
            if await repository.add(draft) {
                dismiss()
            }
        }
    }
}
