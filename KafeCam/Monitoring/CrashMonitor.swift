//
//  CrashMonitor.swift
//  KafeCam
//
//  Facade sobre Sentry. Toda la app usa CrashMonitor — si algún día
//  cambia el proveedor, solo se cambia este archivo.
//
//  Para activar: agregar el paquete Sentry en Xcode (File → Add Packages):
//    https://github.com/getsentry/sentry-cocoa  from: "8.0.0"
//  Y poner el DSN real en KafeCamSecrets.xcconfig (SENTRY_DSN = ...)
//

import Foundation
#if canImport(Sentry)
import Sentry
#endif

enum CrashMonitor {

    // MARK: - Lifecycle

    static func start() {
        guard let dsn = Bundle.main.infoDictionary?["SentryDSN"] as? String,
              !dsn.isEmpty,
              !dsn.hasPrefix("YOUR_") else { return }

        #if canImport(Sentry)
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = isDebug ? "debug" : "production"
            options.enableCrashHandler = true
            options.enableSwiftAsyncStacktraces = true
            options.enableMetricKit = true
            // 20% de transacciones en producción para controlar cuota
            options.tracesSampleRate = isDebug ? 1.0 : 0.2
        }
        #endif
    }

    // MARK: - User identity

    static func identify(userId: String) {
        #if canImport(Sentry)
        SentrySDK.setUser(Sentry.User(userId: userId))
        #endif
    }

    static func clearUser() {
        #if canImport(Sentry)
        SentrySDK.setUser(nil)
        #endif
    }

    // MARK: - Error capture

    /// Captura un error no-fatal con contexto extra para facilitar el debug.
    static func capture(_ error: Error, context: [String: Any] = [:]) {
        #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
            for (key, value) in context {
                scope.setExtra(value: value, key: key)
            }
        }
        #endif
    }

    // MARK: - Breadcrumbs

    /// Registra una acción del usuario. Los últimos N breadcrumbs se adjuntan
    /// automáticamente a cualquier evento (crash o error) que ocurra después.
    static func breadcrumb(_ message: String, category: String) {
        #if canImport(Sentry)
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
        #endif
    }

    // MARK: - Performance

    /// Devuelve un span para medir duración de una operación.
    /// Llamar `.finish()` al terminar.
    static func startSpan(operation: String, description: String) -> Any? {
        #if canImport(Sentry)
        return SentrySDK.startTransaction(name: description, operation: operation)
        #else
        return nil
        #endif
    }

    static func finishSpan(_ span: Any?) {
        #if canImport(Sentry)
        (span as? Sentry.Span)?.finish()
        #endif
    }

    // MARK: - Private

    private static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
