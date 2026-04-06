//
// CaficultoresListView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import SwiftUI

struct FarmersListView: View {
    @StateObject private var vm = FarmersListViewModel()
    let accentColor  = Color(red: 88/255, green: 129/255, blue: 87/255)
    let darkColor    = Color(red: 82/255,  green: 76/255,  blue: 41/255)
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    TextField("Buscar por nombre o teléfono", text: $vm.searchText)
                        .textInputAutocapitalization(.never)
                }
            }
            ForEach(vm.filteredFarmers) { f in
                NavigationLink {
                    FarmerDetailView(farmerId: f.id)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        if vm.isEditing {
                            Button(action: { vm.showDeleteConfirm = f.id }) {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }.buttonStyle(.plain)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.name ?? "(sin nombre)").font(.headline)
                            if let phone = f.phone { Text(phone).font(.subheadline).foregroundStyle(.secondary) }
                            if let email = f.email { Text(email).font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Menu {
                            Button("Asignar por teléfono…") { vm.promptAssignByPhone() }
                            if let id = f.id as UUID? { Button("Quitar asignación", role: .destructive) { vm.unassign(farmerId: id) } }
                        } label: {
                            Image(systemName: "ellipsis.circle").imageScale(.large)
                        }
                    }
                }
            }
        }
        .overlay { if vm.isLoading { ProgressView() } }
        .navigationTitle("Caficultores")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if vm.isEditing {
                    Button("Listo") { vm.isEditing = false }
                        .foregroundStyle(accentColor)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.isEditing {
                    NavigationLink {
                        AddFarmerView(vm: vm)
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(accentColor)
                    }
                } else {
                    Button("Editar") { vm.isEditing = true }
                        .foregroundStyle(accentColor)
                }
            }
        }
        .task { vm.load() }
        .alert("Asignar por teléfono", isPresented: $vm.showAssignPrompt) {
            TextField("Teléfono (10 dígitos)", text: $vm.assignPhone)
            Button("Asignar") { vm.assignByPhone() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Ingresa el teléfono del productor a asignar")
        }
        .alert("Quitar asignación", isPresented: Binding<Bool>(
            get: { vm.showDeleteConfirm != nil },
            set: { if !$0 { vm.showDeleteConfirm = nil } }
        )) {
            Button("Cancelar", role: .cancel) { vm.showDeleteConfirm = nil }
            Button("Quitar", role: .destructive) {
                if let id = vm.showDeleteConfirm { vm.unassign(farmerId: id) }
            }
        } message: {
            Text("¿Seguro que deseas quitar este farmer de tu firma?")
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
    }
}

#Preview {
    FarmersListView()
}
