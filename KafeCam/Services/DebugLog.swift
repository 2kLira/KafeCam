//
// DebugLog.swift
// KafeCam
//
// Debug-only logging helper. All print() calls should use this instead.
//

import Foundation

/// Prints only in DEBUG builds. Use instead of print() throughout the app.
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}
