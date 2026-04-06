//
// AddCaficultorView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 02/10/25
//

import SwiftUI

struct AddFarmerView: View {
    @ObservedObject var vm: FarmersListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var isSearching = false
    @State private var successMessage: String? = nil
    @State private var showSuccessAlert: Bool = false

    var body: some View {
        Form {
            Section("Nombres y apellidos") {
                TextField("Nombres", text: $firstName).textInputAutocapitalization(.words)
                TextField("Apellidos", text: $lastName).textInputAutocapitalization(.words)
            }
            Section("Contacto") {
                TextField("Teléfono (10 dígitos)", text: $phone)
                    .keyboardType(.numberPad)
            }
            Section {
                Button(action: { Task { await search() } }) {
                    HStack { Spacer(); Text("Enviar solicitud").fontWeight(.semibold).foregroundColor(.white); Spacer() }
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 12).fill(Color(red: 88/255, green: 129/255, blue: 87/255)))
                .disabled(isSearching)
            }
            if let _ = successMessage { EmptyView() }
            if let err = vm.errorMessage { Text(err).foregroundStyle(.red) }
        }
        .navigationTitle("Agregar farmer")
        .alert("Confirmado", isPresented: $showSuccessAlert) {
            Button("OK") { showSuccessAlert = false; successMessage = nil }
        } message: { Text(successMessage ?? "") }
    }

    private func search() async {
        vm.errorMessage = nil
        successMessage = nil
        isSearching = true
        defer { isSearching = false }
        let ok = await vm.searchAndRequest(firstName: firstName, lastName: lastName, phone: phone)
        if ok { successMessage = "Solicitud enviada"; showSuccessAlert = true }
    }
}

#Preview { NavigationStack { AddFarmerView(vm: FarmersListViewModel()) } }


