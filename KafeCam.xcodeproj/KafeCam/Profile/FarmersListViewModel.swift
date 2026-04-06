//
// CaficultoresListViewModel.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
import SwiftUI

@MainActor
final class FarmersListViewModel: ObservableObject {
    @Published var farmers: [TechnicianAssignmentsRepository.FarmerSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showAssignPrompt: Bool = false
    @Published var assignPhone: String = ""
    @Published var searchText: String = ""
    @Published var isEditing: Bool = false
    @Published var showDeleteConfirm: UUID? = nil

    private let repo = TechnicianAssignmentsRepository()
    private let requestsRepo = AssignmentRequestsRepository()

    func load() {
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            farmers = try await repo.listFarmersForCurrentTechnician()
        } catch {
            errorMessage = "No se pudieron cargar los farmers"
        }
    }

    func promptAssignByPhone() { assignPhone = ""; showAssignPrompt = true }

    func assignByPhone() {
        Task {
            do {
                let phone = assignPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                guard phone.count == 10 else { self.errorMessage = "Teléfono inválido"; return }
                if let farmer = try await findProfileByPhone(phone) {
                    try await repo.assign(farmerId: farmer.id)
                    await refresh()
                } else {
                    self.errorMessage = "No se encontró un usuario con ese teléfono"
                }
            } catch {
                self.errorMessage = "No se pudo asignar"
            }
            self.showAssignPrompt = false
        }
    }

    func unassign(farmerId: UUID) {
        Task {
            do {
                try await repo.unassign(farmerId: farmerId)
                await refresh()
            } catch {
                self.errorMessage = "No se pudo quitar la asignación"
            }
        }
    }

    private func findProfileByPhone(_ phone: String) async throws -> ProfileDTO? {
        #if canImport(Supabase)
        let list: [ProfileDTO] = try await SupaClient.shared
            .from("profiles")
            .select()
            .eq("phone", value: phone)
            .limit(1)
            .execute()
            .value
        return list.first
        #else
        return nil
        #endif
    }

    var filteredFarmers: [TechnicianAssignmentsRepository.FarmerSummary] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return farmers }
        return farmers.filter {
            ($0.name?.localizedCaseInsensitiveContains(q) ?? false) ||
            ($0.phone?.contains(q) ?? false)
        }
    }

    // Search by exact names + phone and send a request
    func searchAndRequest(firstName: String, lastName: String, phone: String) async -> Bool {
        let full = lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? firstName : "\(firstName) \(lastName)"
        do {
            #if canImport(Supabase)
            // Prefer a SECURITY DEFINER function to avoid RLS recursion
            struct Row: Codable { let id: UUID; let name: String; let phone: String; let email: String? }
            let builder = try SupaClient.shared
                .rpc("search_farmer_exact", params: ["p_name": full, "p_phone": phone])
            let rows: [Row] = try await builder.execute().value
            guard let first = rows.first else { self.errorMessage = "No hay coincidencias"; return false }
            _ = try await requestsRepo.createRequest(farmerId: first.id)
            return true
            #else
            return false
            #endif
        } catch {
            self.errorMessage = "No se pudo enviar la solicitud"
            return false
        }
    }
}
