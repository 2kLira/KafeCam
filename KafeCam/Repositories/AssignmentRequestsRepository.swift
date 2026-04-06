//
// AssignmentRequestsRepository.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 02/10/25
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct AssignmentRequestsRepository {
    #if canImport(Supabase)
    private struct NewRequestPayload: Encodable {
        let technicianId: String
        let farmerId: String
        enum CodingKeys: String, CodingKey { case technicianId = "technician_id"; case farmerId = "farmer_id" }
    }

    func listOutgoing() async throws -> [AssignmentRequestDTO] {
        let tech = try await SupaAuthService.currentUserId()
        let rows: [AssignmentRequestDTO] = try await SupaClient.shared
            .from("assignment_requests")
            .select()
            .eq("technician_id", value: tech.uuidString)
            .order("created_at", ascending: false)
            .execute().value
        return rows
    }

    func listIncoming() async throws -> [AssignmentRequestDTO] {
        let me = try await SupaAuthService.currentUserId()
        let rows: [AssignmentRequestDTO] = try await SupaClient.shared
            .from("assignment_requests")
            .select()
            .eq("farmer_id", value: me.uuidString)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute().value
        return rows
    }

    func createRequest(farmerId: UUID) async throws -> AssignmentRequestDTO {
        let tech = try await SupaAuthService.currentUserId()
        let payload = NewRequestPayload(technicianId: tech.uuidString, farmerId: farmerId.uuidString)
        // Upsert to treat duplicate pending as idempotent success
        do {
            let row: AssignmentRequestDTO = try await SupaClient.shared
                .from("assignment_requests")
                .upsert(payload, onConflict: "technician_id,farmer_id,status")
                .select().single()
                .execute().value
            return row
        } catch {
            // If unique violation occurs, fetch the existing pending row and return it
            let msg = String(describing: error).lowercased()
            if msg.contains("duplicate") || msg.contains("23505") || msg.contains("unique") {
                let rows: [AssignmentRequestDTO] = try await SupaClient.shared
                    .from("assignment_requests")
                    .select()
                    .eq("technician_id", value: tech.uuidString)
                    .eq("farmer_id", value: farmerId.uuidString)
                    .eq("status", value: "pending")
                    .limit(1)
                    .execute().value
                if let first = rows.first { return first }
            }
            throw error
        }
    }

    func respond(requestId: UUID, accept: Bool) async throws {
        let _: Void = try await SupaClient.shared
            .rpc("respond_assignment_request", params: [
                "req_id": requestId.uuidString,
                "accept": accept ? "true" : "false"
            ])
            .execute().value
    }
    #else
    func listOutgoing() async throws -> [AssignmentRequestDTO] { [] }
    func listIncoming() async throws -> [AssignmentRequestDTO] { [] }
    func createRequest(farmerId: UUID) async throws -> AssignmentRequestDTO { throw NSError(domain: "supabase", code: -1) }
    func respond(requestId: UUID, accept: Bool) async throws { }
    #endif
}


