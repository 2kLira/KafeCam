import SwiftUI

struct CommunityOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var avatarStore: AvatarStore
    @State private var step: Int = 0 // 0..2
    @State private var gender: String = ""
    @State private var dob: Date = Date()
    @State private var age: String = ""
    @State private var country: String = ""
    @State private var state: String = ""
    @State private var about: String = ""
    @State private var showCamera = false
    @State private var showDobSheet = false
    @State private var selfie: UIImage? = nil
    let onComplete: () -> Void

    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill").font(.system(size: 56)).foregroundStyle(accentColor)
                        Text("¡Bienvenido a la comunidad Káapeh!")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(accentColor)
                        Text("Para ingresar, llena los siguientes datos")
                            .foregroundStyle(.secondary)
                        AuthCard {
                            if step == 0 {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Género").font(.subheadline).foregroundStyle(.secondary)
                                    Picker("Género", selection: $gender) {
                                        Text("Seleccionar").tag("")
                                        Text("Masculino").tag("male")
                                        Text("Femenino").tag("female")
                                        Text("Otro").tag("other")
                                    }
                                    .pickerStyle(.menu)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Fecha de nacimiento").font(.subheadline).foregroundStyle(.secondary)
                                    Button {
                                        showDobSheet = true
                                    } label: {
                                        HStack {
                                            Text(dob.formatted(date: .abbreviated, time: .omitted)).foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.down").foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                ktextfild(title: "Edad", text: $age, keyboard: .numberPad, contentType: .none)
                                ktextfild(title: "País", text: $country, keyboard: .default, contentType: .countryName)
                                ktextfild(title: "Estado", text: $state, keyboard: .default, contentType: .addressState)
                            } else if step == 1 {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Platícanos sobre ti… ¿Quién eres? ¿A qué te dedicas? ¿Qué te gusta hacer?")
                                        .font(.subheadline)
                                    ZStack(alignment: .topLeading) {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(.systemBackground))
                                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
                                        TextEditor(text: $about)
                                            .frame(minHeight: 160)
                                            .padding(12)
                                    }
                                }
                            } else {
                                VStack(spacing: 12) {
                                    Text("Por último, ¡Tómate una selfie!").font(.headline)
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)).frame(height: 220)
                                        if let img = selfie {
                                            Image(uiImage: img).resizable().scaledToFill().frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 16))
                                        } else {
                                            Image(systemName: "person.crop.square.fill").font(.system(size: 64)).foregroundStyle(.secondary)
                                        }
                                    }
                                    Button("Tomar foto") { showCamera = true }
                                        .buttonStyle(.borderedProminent)
                                        .tint(accentColor)
                                }
                            }
                        }
                        // Dots below the form
                        HStack(spacing: 8) {
                            ForEach(0..<3) { i in
                                Circle().fill(i == step ? accentColor : Color(.systemGray4)).frame(width: 8, height: 8)
                            }
                        }
                        // Centered navigation buttons
                        HStack(spacing: 16) {
                            if step > 0 { Button("Atrás") { withAnimation { step -= 1 } }.buttonStyle(.bordered) }
                            if step < 2 {
                                Button("Siguiente") { withAnimation { step += 1 } }
                                    .buttonStyle(.borderedProminent)
                                    .tint(accentColor)
                                    .disabled(!canProceed)
                            } else {
                                Button("Unir") { Task { await completeOnboarding() } }
                                    .buttonStyle(.borderedProminent)
                                    .tint(accentColor)
                                    .disabled(!canFinish)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                }
                .navigationTitle("")
                .navigationBarHidden(true)
                
                // Close button 
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(source: .camera) { img in
                selfie = img
            }
        }
        .sheet(isPresented: $showDobSheet) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Listo") { showDobSheet = false }
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                }
                DatePicker("", selection: $dob, in: minDob()...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "es_ES"))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .presentationDetents([.height(330)])
        }
        .onAppear {
            let today = Date()
            let min = minDob()
            if dob > today { dob = today }
            if dob < min { dob = min }
        }
    }

    private var canFinish: Bool {
        !gender.isEmpty && !country.trimmingCharacters(in: .whitespaces).isEmpty && !state.trimmingCharacters(in: .whitespaces).isEmpty && !(Int(age) ?? 0 <= 0) && selfie != nil && !about.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canProceed: Bool {
        if step == 0 {
            return !gender.isEmpty && !country.trimmingCharacters(in: .whitespaces).isEmpty && !state.trimmingCharacters(in: .whitespaces).isEmpty && !(Int(age) ?? 0 <= 0)
        } else if step == 1 {
            return !about.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func completeOnboarding() async {
        // Save profile fields (including bio and visibility)
        let repo = ProfilesRepository()
        let ageInt = Int(age) ?? 0
        do {
            _ = try await repo.upsertCurrentUserProfile(
                name: nil,
                email: nil,
                phone: nil,
                organization: nil,
                gender: gender,
                dateOfBirth: dob,
                age: ageInt,
                country: country,
                state: state,
                about: about,
                showGender: true,
                showDateOfBirth: true,
                showAge: true,
                showCountry: true,
                showState: true,
                showAbout: true
            )
        } catch {
            debugPrint("[CommunityOnboarding] upsert error: \(error)")
        }
        if let img = selfie {
            // Set avatar locally and upload best-effort
            await MainActor.run {
                avatarStore.set(image: img, key: "community-selfie.jpg")
            }
            await uploadSelfie(img)
        }
        onComplete()
    }

    private func uploadSelfie(_ image: UIImage) async {
        #if canImport(Supabase)
        do {
            guard let data = image.jpegData(compressionQuality: 0.9) else { return }
            let userId = try await SupaAuthService.currentUserId()
            let ts = Int(Date().timeIntervalSince1970)
            let versionedKey = "\(userId.uuidString)-\(ts).jpg"
            let stableKey = "\(userId.uuidString).jpg"
            let storage = StorageRepository()
            try await storage.upload(bucket: "avatars", objectKey: versionedKey, data: data, contentType: "image/jpeg", upsert: true)
            try await storage.upload(bucket: "avatars", objectKey: stableKey, data: data, contentType: "image/jpeg", upsert: true)
            try await SupaAuthService.updateAuthAvatar(avatarKey: versionedKey)
        } catch {
            debugPrint("[CommunityOnboarding] avatar upload error: \(error)")
        }
        #endif
    }
}

private func minDob() -> Date {
    Calendar.current.date(byAdding: .year, value: -120, to: Date()) ?? Date(timeIntervalSince1970: 0)
}
