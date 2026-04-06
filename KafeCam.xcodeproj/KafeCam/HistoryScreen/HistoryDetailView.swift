import SwiftUI

struct HistoryDetailView: View {
    @EnvironmentObject var historyStore: HistoryStore
    let entry: HistoryEntry
    @State private var notes: String = ""
    @State private var isEditingNotes = false
    @State private var showSaveConfirmation = false
    @State private var isSavingNotes = false
    @FocusState private var notesFieldFocused: Bool
    
    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(uiImage: entry.image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                    .padding()

                Text(entry.prediction)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Notes Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Notas", systemImage: "note.text")
                            .font(.headline)
                            .foregroundColor(accentColor)
                        
                        Spacer()
                        
                        if !isEditingNotes && !notes.isEmpty {
                            Button {
                                isEditingNotes = true
                                notesFieldFocused = true
                            } label: {
                                Text("Editar")
                                    .font(.subheadline)
                                    .foregroundColor(accentColor)
                            }
                        }
                    }
                    
                    if isEditingNotes {
                        VStack(spacing: 12) {
                            TextEditor(text: $notes)
                                .focused($notesFieldFocused)
                                .font(.body)
                                .padding(8)
                                .frame(minHeight: 100, maxHeight: 200)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                                )
                            
                            HStack(spacing: 12) {
                                Button {
                                    // Cancel editing - restore original notes
                                    notes = entry.captureData?.notes ?? ""
                                    isEditingNotes = false
                                    notesFieldFocused = false
                                } label: {
                                    Text("Cancelar")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(10)
                                }
                                
                                Button {
                                    saveNotes()
                                } label: {
                                    if isSavingNotes {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(accentColor)
                                            .cornerRadius(10)
                                    } else {
                                        Text("Guardar")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(accentColor)
                                            .cornerRadius(10)
                                    }
                                }
                                .disabled(isSavingNotes)
                            }
                        }
                    } else {
                        // Display mode
                        Text(notes.isEmpty ? "Toca para agregar notas sobre esta captura..." : notes)
                            .font(.body)
                            .foregroundColor(notes.isEmpty ? .secondary : .primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .onTapGesture {
                                isEditingNotes = true
                                notesFieldFocused = true
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Button {
                    historyStore.toggleFavorite(for: entry)
                } label: {
                    Label(entry.isFavorite ? "Quitar de Favoritos" : "Agregar a Favoritos",
                          systemImage: entry.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(entry.isFavorite ? .red : .accentColor)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load existing notes if available
            notes = entry.captureData?.notes ?? ""
        }
        .alert("Notas guardadas", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Las notas se han guardado correctamente.")
        }
    }
    
    private func saveNotes() {
        print("[HistoryDetail] saveNotes called - notes: '\(notes)'")
        print("[HistoryDetail] entry.captureData is \(entry.captureData != nil ? "present" : "nil")")
        
        guard let captureData = entry.captureData else { 
            print("[HistoryDetail] No captureData available - cannot save notes to database")
            // Still update locally
            historyStore.updateNotes(for: entry, notes: notes)
            isEditingNotes = false
            showSaveConfirmation = true
            return 
        }
        
        isSavingNotes = true
        notesFieldFocused = false
        
        Task {
            #if canImport(Supabase)
            do {
                print("[HistoryDetail] Saving notes for capture ID: \(captureData.id)")
                let repo = CapturesRepository()
                let updated = try await repo.updateNotes(captureId: captureData.id, notes: notes.isEmpty ? nil : notes)
                print("[HistoryDetail] Notes saved successfully. Updated capture has notes: '\(updated.notes ?? "nil")'")
                
                // Update the local entry
                await MainActor.run {
                    historyStore.updateNotes(for: entry, notes: notes)
                    isEditingNotes = false
                    showSaveConfirmation = true
                    isSavingNotes = false
                }
            } catch {
                print("[HistoryDetail] Error saving notes: \(error)")
                await MainActor.run {
                    isSavingNotes = false
                    // Still show confirmation for local save
                    historyStore.updateNotes(for: entry, notes: notes)
                    isEditingNotes = false
                    showSaveConfirmation = true
                }
            }
            #else
            await MainActor.run {
                historyStore.updateNotes(for: entry, notes: notes)
                isEditingNotes = false
                showSaveConfirmation = true
                isSavingNotes = false
            }
            #endif
        }
    }
}

