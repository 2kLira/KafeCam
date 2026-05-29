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

    /// Flujo de asignación técnico↔caficultor (lista de farmers, peticiones,
    /// solicitudes, técnico asignado, notificación al técnico, contacto en
    /// "Pedir ayuda"). Apagado porque el backend de v1 NO tiene las tablas
    /// `assignment_requests` / `technician_farmers` ni las RPCs
    /// `search_farmer_exact` / `respond_assignment_request` /
    /// `list_technicians_for_current_farmer`, y la Edge Function
    /// `notify-technician` no está desplegada. Es una característica de v2.
    /// El código permanece compilado pero inaccesible mientras esté en false.
    static let assignmentsEnabled = false
}
