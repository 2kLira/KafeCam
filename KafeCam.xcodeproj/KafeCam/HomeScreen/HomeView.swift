//
//  HomeView.swift
//  KafeCam
//
//  Created by Grecia Saucedo on 08/09/25.
//

import SwiftUI
import UIKit
import MapKit

private enum AppTab {
    case home, community, map, favorites
}

struct HomeView: View {
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("profileInitials") private var profileInitials: String = ""
    @AppStorage("avatarKey") private var avatarKey: String = ""
    @StateObject private var vm = HomeViewModel()

    // ✅ Instancia global del mapa: vive todo el tiempo y escucha notificaciones
    @StateObject private var plotsVM = PlotsMapViewModel()

    // ✅ Store compartido ya viene por EnvironmentObject desde arriba
    @EnvironmentObject var historyStore: HistoryStore

    @State private var query: String = ""
    @State private var selectedDisease: DiseaseModel? = nil
    @State private var openDiseaseDetail: Bool = false
    
    @State private var selectedTab: AppTab = .home
    
    init() {
        // Configure liquid glass tab bar appearance immediately on init
        let appearance = UITabBarAppearance()
        
        // Clear background for glass effect
        appearance.configureWithTransparentBackground()
        
        // Apply ultra thin material blur
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        
        // Very transparent tint to see through
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.1)
        
        // No shadows for clean glass look
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        
        // Apply globally
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
        
        // Clear any background images
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()
    }

    // filtro simple (sobre la enciclopedia)
    private var filteredDiseases: [DiseaseModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        // Filtra por nombre (ajusta si tu modelo tiene más campos como altNames/tags)
        let hits = diseases.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        return Array(hits.prefix(10))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // INICIO
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        Header(displayName: displayName,
                               greetingName: vm.greetingName,
                               accent: vm.accentColor,
                               dark: vm.darkColor,
                               initials: profileInitials)

                        // buscador
                        SearchBar(text: $query)

                        // coincidencias
                        MatchesList(filtered: filteredDiseases, onTap: { disease in
                            selectedDisease = disease
                            openDiseaseDetail = true
                        })

                        // alertas
                        if !vm.alerts.isEmpty {
                            Text("Alertas")
                                .font(.headline)
                                .foregroundColor(vm.accentColor)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(vm.alerts) { alert in
                                        AlertCard(alert: alert)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }

                        Text("¿Qué quieres hacer hoy?")
                            .foregroundColor(vm.accentColor)
                            .fontWeight(.semibold)

                        // grid de acciones
                        ActionsGrid()
                    }
                    .padding(.horizontal)
                }
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
                .onAppear { vm.refresh() }
                .task { await syncProfileToAppStorage() }
                .navigationDestination(isPresented: $openDiseaseDetail) {
                    if let d = selectedDisease {
                        DiseaseDetailView(disease: d)
                    }
                }
            }
            .tabItem { Label("Inicio", systemImage: "house.fill") }
            .tag(AppTab.home)

            // COMUNIDAD
            NavigationStack {
                CommunityListView()
            }
            .tabItem { Label("Comunidad", systemImage: "person.3.fill") }
            .tag(AppTab.community)

            // MAPA (usa el EnvironmentObject global)
            MapTabView()
                .tabItem { Label("Mapa", systemImage: "map.fill") }
                .tag(AppTab.map)

            // FAVORITOS (usa la misma instancia del store inyectado arriba)
            FavoritesView()
                .tabItem { Label("Favoritos", systemImage: "heart.fill") }
                .tag(AppTab.favorites)
        }
        // ✅ Inyectamos el VM del mapa a TODO el TabView
        .environmentObject(plotsVM)
        .tint(vm.accentColor)
        // 👇 LÍNEA CLAVE: hace que toda la UI use el idioma elegido en Perfil
        .environment(\.locale, LanguageManager.shared.currentLocale)
        .onReceive(NotificationCenter.default.publisher(for: .switchToHomeTab)) { _ in
            selectedTab = .home
        }
    }

    // sincroniza nombre e iniciales
    private func syncProfileToAppStorage() async {
        do {
            let userId = try await SupaAuthService.currentUserId()
            let loginCode = try? await SupaAuthService.currentLoginCode()
            
            debugPrint("[HomeView] Session User ID: \(userId)")
            debugPrint("[HomeView] Login Code: \(loginCode ?? "none")")
            
            // Clear avatar immediately on user switch
            let last = UserDefaults.standard.string(forKey: "lastUserId")
            if last != userId.uuidString {
                UserDefaults.standard.set(userId.uuidString, forKey: "lastUserId")
                NotificationCenter.default.post(name: .init("kafe.user.changed"), object: nil)
            }

            let repo = ProfilesRepository()
            let p = try await repo.getOrCreateCurrent()

            debugPrint("[HomeView] Profile loaded - Name: \(p.name ?? "nil"), Phone: \(p.phone ?? "nil"), Email: \(p.email ?? "nil")")

            let fullName = p.name ?? ""
            let firstName = fullName.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? fullName

            UserDefaults.standard.set(firstName, forKey: "displayName")
            let initials = Self.makeInitials(from: fullName)
            UserDefaults.standard.set(initials, forKey: "profileInitials")

            debugPrint("[HomeView] Display Name set to: \(firstName)")
            debugPrint("[HomeView] Initials set to: \(initials)")

            // Store avatar key so header/community can load avatar without visiting profile first
            #if canImport(Supabase)
            let session = try await SupaClient.shared.auth.session
            if let key = session.user.userMetadata["avatar_key"]?.stringValue, !key.isEmpty {
                UserDefaults.standard.set(key, forKey: "avatarKey")
            } else {
                // Fallback predictable key (may 404 until user uploads)
                let fallback = "\(userId.uuidString.lowercased()).jpg"
                UserDefaults.standard.set(fallback, forKey: "avatarKey")
            }
            #endif
        } catch {
            debugPrint("[HomeView] Error syncing profile: \(error)")
        }
    }

    private static func makeInitials(from name: String?) -> String {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return "" }
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }
}

extension Notification.Name {
    static let switchToHomeTab = Notification.Name("kafe.switchToHomeTab")
}

// MARK: - Subvistas

private struct Header: View {
    let displayName: String
    let greetingName: String
    let accent: Color
    let dark: Color
    let initials: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hola, \((displayName.isEmpty ? greetingName : displayName)) 👋")
                    .font(.largeTitle.bold())
                    .foregroundColor(accent)
                    .lineLimit(1)

                Text("Todo lo que tu cafetal necesita...")
                    .italic()
                    .foregroundColor(dark)
                    .fontWeight(.medium)
            }
            Spacer(minLength: 0)
            NavigationLink {
                ProfileTabView()
            } label: {
                HeaderAvatar(initials: initials)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir perfil")
        }
        .padding(.top, 8)
    }
}

private struct HeaderAvatar: View {
    @EnvironmentObject var avatarStore: AvatarStore
    @AppStorage("avatarKey") private var avatarKey: String = ""
    let initials: String
    @State private var image: UIImage? = nil
    var body: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            if let img = avatarStore.image ?? image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Text(initials.isEmpty ? "" : initials)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 40, height: 40)
        .overlay(Circle().stroke(.white, lineWidth: 1))
        .shadow(radius: 3)
        .onAppear { self.image = avatarStore.image }
        .onChange(of: avatarStore.image) { _, img in self.image = img }
    }
}

private struct MatchesList: View {
    let filtered: [DiseaseModel]
    let onTap: (DiseaseModel) -> Void

    var body: some View {
        Group {
            if !filtered.isEmpty {
                Text("Coincidencias").font(.headline)
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filtered) { disease in
                        Button { onTap(disease) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "leaf.fill").foregroundStyle(.secondary)
                                Text(disease.name)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: filtered)
            }
        }
    }
}

private struct ActionsGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {

            // ANTICIPA
            NavigationLink {
                AnticipaView()
            } label: {
                ActionCardView(color: green1, systemImage: "cloud.sun.fill",
                               title: "Anticipa", subtitle: "Prevé el clima")
                    .contentShape(Rectangle())
            }
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            })

            // DETECTA
            NavigationLink {
                DetectaView()
            } label: {
                ActionCardView(color: brown1,
                               systemImage: "camera.fill",
                               title: "Detecta",
                               subtitle: "Prevención temprana")
                    .contentShape(Rectangle())
            }
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            })

            // INFÓRMATE
            NavigationLink {
                DiseaseView(diseaseList: diseases)
            } label: {
                ActionCardView(color: brown2, systemImage: "bandage.fill",
                               title: "Infórmate", subtitle: "Cuida tu cultivo")
                    .contentShape(Rectangle())
            }

            // CONSULTA
            NavigationLink {
                HistoryView()
            } label: {
                ActionCardView(color: green2, systemImage: "leaf.fill",
                               title: "Consulta", subtitle: "Tus registros siempre")
                    .contentShape(Rectangle())
            }
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            })
        }
        .buttonStyle(.plain)
    }
}

private struct MapSectionView: View {
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 15.7845002, longitude: -92.7611756),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    )

    var body: some View {
        NavigationStack {
            Map(position: $position)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Mapa")
        }
    }
}

#Preview {
    HomeView()
        // Previews: provee stores/VMs mínimamente
        .environmentObject(HistoryStore())
}
