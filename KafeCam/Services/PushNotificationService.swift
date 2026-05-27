//
//  PushNotificationService.swift
//  KafeCam
//
//  Gestiona el registro APNs, el guardado del device token en Supabase,
//  y el disparo de notificaciones al técnico cuando un agricultor sube un diagnóstico.
//

import Foundation
import UIKit
import UserNotifications
#if canImport(Supabase)
import Supabase
#endif

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Registration

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            debugLog("[Push] Permission denied")
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
        debugLog("[Push] Registered for remote notifications")
    }

    /// Called by AppDelegate when APNs returns a token.
    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        debugLog("[Push] Device token: \(token)")
        Task { await saveToken(token) }
    }

    // MARK: - Token storage

    private func saveToken(_ token: String) async {
        #if canImport(Supabase)
        guard let uid = try? await SupaAuthService.currentUserId() else { return }
        do {
            struct TokenUpdate: Encodable { let apns_token: String }
            let _: Void = try await SupaClient.shared
                .from("profiles")
                .update(TokenUpdate(apns_token: token))
                .eq("id", value: uid.uuidString)
                .execute()
                .value
            debugLog("[Push] Token saved")
        } catch {
            debugLog("[Push] Failed to save token: \(error)")
        }
        #endif
    }

    // MARK: - Notificar al técnico

    /// Llama a la Edge Function `notify-technician` después de guardar un diagnóstico.
    /// Falla silenciosamente si no hay técnico asignado o no hay red.
    func notifyTechnicianCaptureSaved(captureId: UUID, prediction: String) async {
        #if canImport(Supabase)
        guard let uid = try? await SupaAuthService.currentUserId() else { return }
        do {
            struct Payload: Encodable {
                let farmer_id: String
                let capture_id: String
                let prediction: String
            }
            let body = Payload(
                farmer_id: uid.uuidString,
                capture_id: captureId.uuidString,
                prediction: prediction
            )
            try await SupaClient.shared.functions
                .invoke("notify-technician", options: .init(body: body))
            debugLog("[Push] Edge Function invoked")
        } catch {
            // No notificar error al usuario — la notificación es best-effort
            debugLog("[Push] notify-technician failed (ignorado): \(error)")
        }
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    /// Mostrar el banner aunque la app esté en primer plano
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Responder al tap en la notificación
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let captureId = userInfo["capture_id"] as? String {
            debugLog("[Push] Tap en captura: \(captureId)")
            // Navegar a la captura — emitir notificación para que la UI reaccione
            NotificationCenter.default.post(
                name: .kafeOpenCapture,
                object: nil,
                userInfo: ["capture_id": captureId]
            )
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let kafeOpenCapture = Notification.Name("kafe.openCapture")
}
