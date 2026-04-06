//
// StorageRepository.swift
// KafeCam
//
// Created by AI Assistant on 16/10/25
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct StorageRepository {
    #if canImport(Supabase)
    private struct SignResponse: Decodable { let signedURL: String?; let signedUrl: String? }
    private struct ListRequest: Encodable { let prefix: String; let limit: Int; let offset: Int; let sortBy: SortBy?; struct SortBy: Encodable { let column: String; let order: String } }
    private struct ListEntry: Decodable { let name: String }

    /// Returns a signed download URL for an object in the `captures` bucket by default.
    func signedDownloadURL(objectKey: String, bucket: String = "captures", expiresIn: Int = 3600) async throws -> URL {
        let session = try await SupaClient.shared.auth.session
        let tokenMirror = Mirror(reflecting: session)
        let accessToken = (tokenMirror.children.first { $0.label == "accessToken" }?.value as? String) ?? ""

        var base = SupabaseConfig.url.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        let endpoint = URL(string: base + "/storage/v1/object/sign/\(bucket)/" + objectKey)!

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        let body = ["expiresIn": expiresIn]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let s = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "storage", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "sign failed: \(s)"])
        }

        let signed = try JSONDecoder().decode(SignResponse.self, from: data)
        guard let path = signed.signedURL ?? signed.signedUrl else {
            throw NSError(domain: "storage", code: -2, userInfo: [NSLocalizedDescriptionKey: "signed url missing"])
        }
        let full = URL(string: base + "/storage/v1/" + path)!
        return full
    }

    /// Builds a public URL (no signing). Works only for public buckets or if RLS allows anon read via apikey.
    func publicURL(objectKey: String, bucket: String = "captures") -> URL {
        var base = SupabaseConfig.url.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        // Ensure proper path encoding of objectKey
        let encoded = objectKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectKey
        let url = URL(string: base + "/storage/v1/object/public/\(bucket)/" + encoded)!
        return url
    }

    /// Lists objects in a bucket under a given prefix (best-effort fallback for discovering avatar keys).
    func listObjects(bucket: String, prefix: String, limit: Int = 20) async throws -> [String] {
        var base = SupabaseConfig.url.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        let endpoint = URL(string: base + "/storage/v1/object/list/\(bucket)")!

        let session = try await SupaClient.shared.auth.session
        let tokenMirror = Mirror(reflecting: session)
        let accessToken = (tokenMirror.children.first { $0.label == "accessToken" }?.value as? String) ?? ""

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        let body = ListRequest(prefix: prefix, limit: limit, offset: 0, sortBy: .init(column: "name", order: "desc"))
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let s = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "storage", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "list failed: \(s)"])
        }
        let entries = try JSONDecoder().decode([ListEntry].self, from: data)
        return entries.map { $0.name }
    }

    /// Uploads data to Supabase Storage using authenticated HTTP request.
    /// If `upsert` is true, existing object will be overwritten.
    func upload(bucket: String, objectKey: String, data: Data, contentType: String, upsert: Bool = true) async throws {
        let session = try await SupaClient.shared.auth.session
        let tokenMirror = Mirror(reflecting: session)
        // Try common property names for access token
        let accessToken = (tokenMirror.children.first { $0.label == "accessToken" }?.value as? String) ?? ""

        var base = SupabaseConfig.url.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        let endpoint = URL(string: base + "/storage/v1/object/\(bucket)/" + objectKey)!

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"               // Storage accepts POST with x-upsert for create/replace
        req.addValue(contentType, forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.addValue(upsert ? "true" : "false", forHTTPHeaderField: "x-upsert")
        req.httpBody = data

        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: respData, encoding: .utf8) ?? ""
            throw NSError(domain: "storage", code: code, userInfo: [NSLocalizedDescriptionKey: "upload failed: status=\(code) body=\"\(body)\""])
        }
    }
    #else
    func signedDownloadURL(objectKey: String, bucket: String = "captures", expiresIn: Int = 3600) async throws -> URL { throw NSError(domain: "supabase", code: -1) }
    func upload(bucket: String, objectKey: String, data: Data, contentType: String, upsert: Bool = true) async throws { throw NSError(domain: "supabase", code: -1) }
    func publicURL(objectKey: String, bucket: String = "captures") -> URL { URL(fileURLWithPath: "/dev/null") }
    func listObjects(bucket: String, prefix: String, limit: Int = 20) async throws -> [String] { [] }
    #endif
}

