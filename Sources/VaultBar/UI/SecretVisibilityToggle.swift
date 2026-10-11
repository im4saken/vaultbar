import SwiftUI

/// Eye button shown next to an API/Token field.
/// Closed eye (`eye.slash`) = hidden, click to show; open eye (`eye`) = shown, click to hide.
struct SecretVisibilityToggle: View {
    @Binding var isRevealed: Bool

    var body: some View {
        Button {
            isRevealed.toggle()
        } label: {
            Image(systemName: isRevealed ? "eye" : "eye.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isRevealed ? "隐藏 API/Token" : "显示 API/Token")
        .accessibilityLabel(isRevealed ? "隐藏 API/Token" : "显示 API/Token")
    }
}
