//
// CaficultorDetailView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 02/10/25
//

import SwiftUI

struct FarmerDetailView: View {
    let farmerId: UUID
    @StateObject private var vm = FarmerDetailViewModel()
    let accentColor  = Color(red: 88/255, green: 129/255, blue: 87/255)
    
    var body: some View {
        List {
            if let p = vm.profile {
                Section("Perfil") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(p.name ?? "(sin nombre)").font(.headline)
                        if let email = p.email, !email.isEmpty { Text(email).foregroundStyle(.secondary) }
                        if let phone = p.phone, !phone.isEmpty { Text(phone).foregroundStyle(.secondary) }
                        if let org = p.organization, !org.isEmpty { Text(org).foregroundStyle(.secondary) }
                    }
                }
            }
            if !vm.plots.isEmpty {
                Section("Lotes") {
                    ForEach(vm.plots, id: \.id) { plot in
                        VStack(alignment: .leading) {
                            Text(plot.name).font(.headline)
                            HStack(spacing: 12) {
                                if let lat = plot.lat, let lon = plot.lon {
                                    Text("\(lat, specifier: "%.4f"), \(lon, specifier: "%.4f")").font(.caption).foregroundStyle(.secondary)
                                }
                                if let region = plot.region { Text(region).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
            if !vm.captures.isEmpty {
                Section("Fotos") {
                    ForEach(vm.captures, id: \.id) { cap in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cap.deviceModel ?? "Foto")
                            Text(cap.takenAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Detalle del farmer")
        .tint(accentColor)
        .task { await vm.load(farmerId: farmerId) }
        .overlay { if vm.isLoading { ProgressView() } }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
    }
}

final class FarmerDetailViewModel: ObservableObject {
    @Published var profile: ProfileDTO? = nil
    @Published var plots: [PlotDTO] = []
    @Published var captures: [CaptureDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let profilesRepo = ProfilesRepository()
    private let plotsRepo = PlotsRepository()
    private let capturesRepo = CapturesRepository()
    
    @MainActor
    func load(farmerId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await profilesRepo.get(byId: farmerId)
            plots = try await plotsRepo.listPlots(ownerUserId: farmerId)
            captures = try await capturesRepo.listCaptures(uploadedBy: farmerId)
        } catch {
            errorMessage = "No se pudo cargar la información del farmer"
        }
    }
}

#Preview { NavigationStack { FarmerDetailView(farmerId: UUID()) } }


