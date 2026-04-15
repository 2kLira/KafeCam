//
//  GuestLoginPromptView.swift
//  KafeCam
//

import SwiftUI

struct GuestLoginPromptView: View {
    @EnvironmentObject var session: SessionViewModel

    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(accentColor)

            Text("Inicia sesión para acceder")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Esta sección requiere una cuenta. Crea una gratis o inicia sesión para continuar.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Iniciar sesión") {
                session.isGuest = false
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .controlSize(.large)

            Spacer()
        }
    }
}
