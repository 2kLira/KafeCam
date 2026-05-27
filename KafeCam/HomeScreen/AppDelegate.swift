//
//  AppDelegate.swift
//  KafeCam
//
//  Recibe el device token de APNs y lo pasa a PushNotificationService.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        debugLog("[Push] Registro APNs falló: \(error.localizedDescription)")
    }
}
