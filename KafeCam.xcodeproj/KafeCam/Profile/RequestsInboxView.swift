//
// RequestsInboxView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 02/10/25
//

import SwiftUI

struct RequestsInboxView: View {
    @State private var requests: [AssignmentRequestDTO] = []
    @State private var isWorking: Bool = false
    @State private var error: String? = nil
    @State private var success: String? = nil
    @State private var confirmRequest: AssignmentRequestDTO? = nil
    @State private var showAcceptConfirm: Bool = false
    @State private var showRejectConfirm: Bool = false
    private let repo = AssignmentRequestsRepository()

    init(requests: [AssignmentRequestDTO]) {
        self._requests = State(initialValue: requests)
    }

    var body: some View {
        List {
            if requests.isEmpty { Text("No tienes peticiones") }
            ForEach(requests) { r in
                HStack {
                    VStack(alignment: .leading) {
                        Text("Solicitud de técnico")
                        Text(r.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 20) {
                        Button { confirmRequest = r; showAcceptConfirm = true } label: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
                        }
                        .buttonStyle(.borderless)
                        Button { confirmRequest = r; showRejectConfirm = true } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.title2)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .contentShape(Rectangle()) // disable implicit row tap behavior
            }
        }
        .navigationTitle("Peticiones")
        .overlay { if isWorking { ProgressView() } }
        .task { await refresh() }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .alert("Confirmado", isPresented: .constant(success != nil)) {
            Button("OK") { success = nil }
        } message: { Text(success ?? "") }
        .alert("Confirmar", isPresented: $showAcceptConfirm) {
            Button("Cancelar", role: .cancel) { confirmRequest = nil; showAcceptConfirm = false }
            Button("Aceptar") {
                if let req = confirmRequest { Task { await respond(req, accept: true) } }
                confirmRequest = nil; showAcceptConfirm = false
            }
        } message: { Text("¿Aceptar solicitud?") }
        .alert("Confirmar", isPresented: $showRejectConfirm) {
            Button("Cancelar", role: .cancel) { confirmRequest = nil; showRejectConfirm = false }
            Button("Rechazar", role: .destructive) {
                if let req = confirmRequest { Task { await respond(req, accept: false) } }
                confirmRequest = nil; showRejectConfirm = false
            }
        } message: { Text("¿Rechazar solicitud?") }
    }

    @MainActor private func refresh() async {
        do {
            requests = try await repo.listIncoming()
        } catch {
            // ignore load errors; keep current
        }
    }

    @MainActor private func respond(_ r: AssignmentRequestDTO, accept: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await repo.respond(requestId: r.id, accept: accept)
            success = accept ? "Te uniste a la firma" : "Solicitud rechazada"
            if let idx = requests.firstIndex(where: { $0.id == r.id }) { requests.remove(at: idx) }
            await refresh()
        } catch {
            // If another accepted already exists for the same pair, treat as success
            let msg = String(describing: error).lowercased()
            if msg.contains("duplicate key") || msg.contains("unique constraint") || msg.contains("23505") || msg.contains("not found or not yours") {
                success = accept ? "Te uniste a la firma" : "Solicitud rechazada"
                if let idx = requests.firstIndex(where: { $0.id == r.id }) { requests.remove(at: idx) }
                await refresh()
            } else {
                self.error = "No se pudo responder a la petición"
            }
        }
    }
}

#Preview { RequestsInboxView(requests: []) }


