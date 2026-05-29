//
//  FeatureFlags.swift
//  KafeCam
//
//  Banderas de funcionalidades. Permite ocultar módulos sin borrar código.
//  Para reactivar Comunidad en el futuro: poner `communityEnabled = true`.
//

import Foundation

enum FeatureFlags {
    /// Pestaña Comunidad y todo su flujo (onboarding incluido).
    /// Mientras esté en false el código permanece compilado pero inaccesible.
    static let communityEnabled = false
}
