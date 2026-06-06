//
//  AppleNonce.swift
//  KafeCam
//
//  Helpers for Sign in with Apple. A random nonce is generated per request; its
//  SHA-256 hash is sent to Apple (request.nonce), and the RAW nonce is sent to
//  Supabase (signInWithIdToken) so the backend can verify the id token's `nonce`
//  claim. This prevents replay attacks.
//

import CryptoKit
import Foundation

enum AppleNonce {
    /// Cryptographically-random nonce string.
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var byte: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
                return byte
            }
            for r in randoms where remaining > 0 {
                if Int(r) < charset.count {
                    result.append(charset[Int(r)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// Lowercase hex SHA-256 of the input (what Apple expects in `request.nonce`).
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
