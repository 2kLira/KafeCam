//
//  BitacoraView.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Cuaderno de campo del caficultor. Lugar para observar, reflexionar
//  y registrar acciones. La IA solo organiza; el experto del cafetal
//  sigue siendo quien escribe.
//

import SwiftUI
import PhotosUI

struct BitacoraView: View {
    @StateObject private var store = BitacoraStore.shared
    @State private var showNewSheet: Bool = false
    @State private var selectedKindFilter: BitacoraEntryKind? = nil

    private var filteredEntries: [BitacoraEntry] {
        guard let k = selectedKindFilter else { return store.entries }
        return store.entries.filter { $0.kind == k }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Header()
                    .kafeSoftEntry(0)

                KindFilterRow(selected: $selectedKindFilter)
                    .kafeSoftEntry(1)

                if filteredEntries.isEmpty {
                    EmptyState(hasFilter: selectedKindFilter != nil)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredEntries) { entry in
                            EntryRow(entry: entry, onDelete: {
                                withAnimation(AppTheme.springList) {
                                    store.delete(entry)
                                }
                            })
                            .transition(.kafeListItem)
                        }
                    }
                    .kafeSoftEntry(2)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
            // Spring keyed to the visible list: inserts rise in, deletes collapse,
            // and neighbors glide into place instead of jumping.
            .animation(AppTheme.springList, value: filteredEntries)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Bitácora")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            AddButton(action: { showNewSheet = true })
                .padding(20)
        }
        .sheet(isPresented: $showNewSheet) {
            NewEntrySheet()
        }
    }
}

// MARK: - Subvistas

private struct Header: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bitácora")
                .font(.largeTitle.bold())
                .foregroundStyle(brown1)

            Text("Lo que pasa en tu cafetal, contado por ti. Aquí guardas observaciones, acciones y aprendizajes.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct KindFilterRow: View {
    @Binding var selected: BitacoraEntryKind?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(label: "Todo", isOn: selected == nil) {
                    selected = nil
                }
                ForEach(BitacoraEntryKind.allCases, id: \.self) { k in
                    FilterChip(label: k.displayName, isOn: selected == k, tint: k.color, icon: k.iconSF) {
                        selected = (selected == k) ? nil : k
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isOn: Bool
    var tint: Color = brown1
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(label)
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isOn ? .white : tint)
            .background(
                Capsule().fill(isOn ? tint : tint.opacity(0.12))
            )
        }
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

private struct EmptyState: View {
    let hasFilter: Bool
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 56))
                .foregroundStyle(brown2)
                .accessibilityHidden(true)
            Text(hasFilter ? "Sin entradas en este filtro" : "Tu bitácora está vacía")
                .font(.headline)
            Text(hasFilter
                 ? "Cambia o quita el filtro para ver más entradas."
                 : "Toca el botón + para empezar a registrar lo que ves en tu cafetal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 24)
    }
}

private struct EntryRow: View {
    let entry: BitacoraEntry
    var onDelete: (() -> Void)? = nil

    @State private var confirmDelete = false

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.locale = LanguageManager.shared.currentLocale
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: entry.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: entry.kind.iconSF)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(entry.kind.color))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(entry.kind.displayName) · \(dateLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                AudioReadButton(text: entry.body, compact: true)

                if onDelete != nil {
                    Button {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.red.opacity(0.75))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Borrar entrada")
                }
            }

            if let data = entry.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
            }

            Text(entry.body)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.kind.displayName), \(dateLabel). \(entry.title). \(entry.body)")
        .confirmationDialog("¿Borrar esta entrada?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { onDelete?() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

private struct AddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(brown1))
                .shadow(color: brown1.opacity(0.4), radius: 8, y: 4)
        }
        .accessibilityLabel("Nueva entrada en bitácora")
        .accessibilityHint("Abre un formulario para registrar una observación, reflexión, foto o acción.")
    }
}

// MARK: - Nueva entrada (sheet)

struct NewEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: BitacoraEntryKind = .observation
    @State private var title: String = ""
    // Renombrado de `body` a `detailsText` para no chocar con `var body: some View`.
    @State private var detailsText: String = ""
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !detailsText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de entrada") {
                    Picker("Tipo", selection: $kind) {
                        ForEach(BitacoraEntryKind.allCases, id: \.self) { k in
                            Label(k.displayName, systemImage: k.iconSF).tag(k)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Título") {
                    TextField("Ej. Manchas amarillas en hojas viejas", text: $title)
                        .accessibilityLabel("Título de la entrada")
                }

                Section("Detalles") {
                    TextEditor(text: $detailsText)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Detalles de la entrada")
                    Text("Describe con tus palabras. Nadie conoce tu parcela mejor que tú.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Foto (opcional)") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack {
                            Image(systemName: imageData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                            Text(imageData == nil ? "Agregar foto" : "Foto agregada")
                        }
                    }
                    if let data = imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .navigationTitle("Nueva entrada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!canSave)
                        .bold()
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }

    private func save() {
        let entry = BitacoraEntry(
            id: UUID().uuidString,
            date: Date(),
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: detailsText.trimmingCharacters(in: .whitespacesAndNewlines),
            imageData: imageData
        )
        // Animate the insertion so the list glides the new row in after the sheet closes.
        withAnimation(AppTheme.springList) {
            BitacoraStore.shared.add(entry)
        }
        dismiss()
    }
}

#Preview {
    BitacoraView()
}
