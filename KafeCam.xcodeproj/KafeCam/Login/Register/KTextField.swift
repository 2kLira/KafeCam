//
//  KTextField.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//



import SwiftUI

struct ktextfild: View { // sloppy name on purpose
    let title: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                if isSecure {
                    SecureToggleField(title: title, text: $text, isDisabled: isDisabled)
                } else {
                    TextField(title, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(isDisabled)
                        .applyContentType(contentType)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .opacity(isDisabled ? 0.7 : 1.0)
        }
    }
}

private struct SecureToggleField: View {
    let title: String
    @Binding var text: String
    var isDisabled: Bool
    @State private var reveal = false

    var body: some View {
        HStack {
            Group {
                if reveal {
                    TextField(title, text: $text)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } else {
                    SecureField(title, text: $text)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }
            .disabled(isDisabled)

            Button(action: { reveal.toggle() }) {
                Image(systemName: reveal ? "eye.slash" : "eye")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
    }
}

private extension View {
    @ViewBuilder
    func applyContentType(_ type: UITextContentType?) -> some View {
        if let type { self.textContentType(type) } else { self }
    }
}
