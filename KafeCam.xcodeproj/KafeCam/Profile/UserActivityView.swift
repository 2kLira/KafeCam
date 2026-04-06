//
//  UserActivityView.swift
//  KafeCam
//
//  Shows user's captures and map activity

import SwiftUI
import MapKit

struct UserActivityView: View {
    let userId: UUID
    @EnvironmentObject var mapViewModel: PlotsMapViewModel // Access shared map view model
    @State private var captures: [CaptureDTO] = []
    @State private var mapPins: [MapPinData] = []
    @State private var plots: [UUID: PlotDTO] = [:] // Store plot data by ID
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var selectedCapture: CaptureDTO? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showImageViewer = false
    @State private var showMapDetail = false
    
    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Activity", selection: $selectedTab) {
                Label("Capturas", systemImage: "camera.fill").tag(0)
                Label("Mapa", systemImage: "map.fill").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if isLoading {
                Spacer()
                ProgressView("Cargando actividad...")
                Spacer()
            } else {
                if selectedTab == 0 {
                    capturesView
                } else {
                    mapActivityView
                }
            }
        }
        .task {
            await loadActivity()
        }
        .sheet(isPresented: $showImageViewer) {
            if let image = selectedImage {
                ImageViewerView(image: image, capture: selectedCapture)
            }
        }
        .sheet(isPresented: $showMapDetail) {
            if !mapPins.isEmpty {
                MapDetailView(pins: mapPins)
            }
        }
    }
    
    private var capturesView: some View {
        ScrollView {
            if captures.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No hay capturas todavía")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(captures) { capture in
                        CaptureGridItem(capture: capture) { image in
                            selectedImage = image
                            selectedCapture = capture
                            showImageViewer = true
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var mapActivityView: some View {
        VStack(spacing: 16) {
            if mapPins.isEmpty {
                Spacer()
                Image(systemName: "map")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No hay actividad en el mapa")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                // Summary stats
                HStack(spacing: 20) {
                    StatCard(
                        icon: "mappin.circle.fill",
                        value: "\(mapPins.count)",
                        label: "Pins totales",
                        color: accentColor
                    )
                    
                    StatCard(
                        icon: "leaf.fill",
                        value: "\(mapPins.filter { $0.status == "sano" }.count)",
                        label: "Sanos",
                        color: .green
                    )
                    
                    StatCard(
                        icon: "exclamationmark.triangle.fill",
                        value: "\(mapPins.filter { $0.status == "sospecha" }.count)",
                        label: "Sospecha",
                        color: .orange
                    )
                    
                    StatCard(
                        icon: "xmark.octagon.fill",
                        value: "\(mapPins.filter { $0.status == "enfermo" }.count)",
                        label: "Enfermo",
                        color: .red
                    )
                }
                .padding(.horizontal)
                
                // Map preview
                MapPreviewCard(pins: mapPins) {
                    showMapDetail = true
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
    
    private func loadActivity() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load captures
        #if canImport(Supabase)
        do {
            let capturesRepo = CapturesRepository()
            captures = try await capturesRepo.listCaptures(uploadedBy: userId)
            
            // Load plots for the captures
            let plotsRepo = PlotsRepository()
            let uniquePlotIds = Set(captures.map { $0.plotId })
            
            for plotId in uniquePlotIds {
                if let plot = try? await plotsRepo.get(byId: plotId) {
                    plots[plotId] = plot
                }
            }
        } catch {
            print("[UserActivity] Error loading captures: \(error)")
        }
        #endif
        
        // Load map pins with actual plot locations
        await loadMapPins()
    }
    
    private func loadMapPins() async {
        // Convert the actual MapPlotPin objects from the shared map view model to MapPinData
        // This ensures we show the EXACT same pins as in the Map tab
        mapPins = mapViewModel.pins.map { pin in
            // Determine status from pin's actual status
            let status: String
            switch pin.status {
            case .sano:
                status = "sano"
            case .sospecha:
                status = "sospecha"
            case .enfermo:
                status = "enfermo"
            }
            
            return MapPinData(
                id: pin.id,
                coordinate: pin.coordinate,
                status: status,
                date: pin.plantedAt ?? Date(),
                deviceModel: pin.name,
                plotId: nil
            )
        }
    }
    
    private func extractStatus(from deviceModel: String) -> String {
        let model = deviceModel.lowercased()
        if model.contains("enferm") || model.contains("roya") || model.contains("manganeso") || model.contains("hierro") || model.contains("potasio") {
            return "enfermo"
        } else if model.contains("sospecha") {
            return "sospecha"
        } else if model.contains("sano") || model.contains("sana") {
            return "sano"
        } else {
            // Default to sospecha for unknown classifications
            return "sospecha"
        }
    }
}

// MARK: - Supporting Views

struct CaptureGridItem: View {
    let capture: CaptureDTO
    let onTap: (UIImage) -> Void
    @State private var image: UIImage? = nil
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .aspectRatio(1, contentMode: .fit)
            
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        onTap(img)
                    }
            } else if isLoading {
                ProgressView()
                    .frame(width: 100, height: 100)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }
            
            // Date badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(capture.takenAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                        .padding(4)
                }
            }
        }
        .frame(width: 100, height: 100)
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(Supabase)
        do {
            let storage = StorageRepository()
            let url = try await storage.signedDownloadURL(
                objectKey: capture.photoKey,
                bucket: "captures",
                expiresIn: 600
            )
            
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                await MainActor.run {
                    self.image = img
                }
            }
        } catch {
            print("[CaptureGrid] Error loading image: \(error)")
        }
        #endif
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MapPreviewCard: View {
    let pins: [MapPinData]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: pins.first?.coordinate ?? CLLocationCoordinate2D(latitude: 15.7846, longitude: -92.7612),
                    span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                )))) {
                    ForEach(pins) { pin in
                        Marker("", coordinate: pin.coordinate)
                            .tint(pin.pinColor)
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)
                .allowsHitTesting(false)
                
                Label("Ver mapa", systemImage: "arrow.up.right.square.fill")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ImageViewerView: View {
    let image: UIImage
    let capture: CaptureDTO?
    @Environment(\.dismiss) var dismiss
    @State private var showMapDetail = false
    
    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Image container with proper aspect ratio
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .background(Color.black)
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
                    
                    // Details panel - EXACTLY like HistoryDetailView in Consulta
                    ScrollView {
                        VStack(spacing: 16) {
                            // Display the full prediction string exactly as in Consulta
                            if let deviceModel = capture?.deviceModel {
                                Text(deviceModel)
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Date - same format as Consulta (abbreviated date, shortened time)
                            if let date = capture?.takenAt {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Notes section (read-only for viewing other users' captures)
                            if let notes = capture?.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Notas", systemImage: "note.text")
                                        .font(.headline)
                                        .foregroundColor(accentColor)
                                    
                                    Text(notes)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal)
                            }
                            
                            // Map button
                            Button {
                                showMapDetail = true
                            } label: {
                                Label("Ver en mapa", systemImage: "map.fill")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    .background(Color(.secondarySystemBackground))
                }
            }
            .navigationTitle("Detalle de Captura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showMapDetail) {
            if let capture = capture {
                SinglePinMapView(capture: capture)
            }
        }
    }
    
}

struct SinglePinMapView: View {
    let capture: CaptureDTO
    @Environment(\.dismiss) var dismiss
    @State private var region: MKCoordinateRegion
    @State private var plot: PlotDTO?
    @State private var actualCoordinate: CLLocationCoordinate2D
    
    init(capture: CaptureDTO) {
        self.capture = capture
        // Default to Chiapas region - will be updated when plot loads
        let center = CLLocationCoordinate2D(latitude: 15.7846, longitude: -92.7612)
        self._actualCoordinate = State(initialValue: center)
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    var body: some View {
        NavigationStack {
            Map(position: .constant(.region(region))) {
                Annotation("", coordinate: actualCoordinate) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(pinColor)
                            .font(.largeTitle)
                        
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Ubicación de captura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadPlotLocation()
        }
    }
    
    private func loadPlotLocation() async {
        #if canImport(Supabase)
        do {
            let plotsRepo = PlotsRepository()
            if let fetchedPlot = try? await plotsRepo.get(byId: capture.plotId) {
                plot = fetchedPlot
                
                if let lat = fetchedPlot.lat, let lon = fetchedPlot.lon {
                    // Use actual plot coordinates
                    actualCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    region = MKCoordinateRegion(
                        center: actualCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                }
            }
        }
        #endif
    }
    
    private var pinColor: Color {
        let model = (capture.deviceModel ?? "").lowercased()
        if model.contains("enferm") || model.contains("roya") || model.contains("manganeso") || model.contains("hierro") || model.contains("potasio") {
            return .red
        } else if model.contains("sospecha") {
            return .orange
        } else if model.contains("sano") || model.contains("sana") {
            return .green
        } else {
            return .gray
        }
    }
    
}

struct MapDetailView: View {
    let pins: [MapPinData]
    @Environment(\.dismiss) var dismiss
    @State private var region: MKCoordinateRegion
    
    init(pins: [MapPinData]) {
        self.pins = pins
        let center = pins.first?.coordinate ?? CLLocationCoordinate2D(latitude: 15.7846, longitude: -92.7612)
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        ))
    }
    
    var body: some View {
        NavigationStack {
            Map(position: .constant(.region(region))) {
                ForEach(pins) { pin in
                    Annotation("", coordinate: pin.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(pin.pinColor)
                            .font(.title)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Actividad en el mapa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Data Models

struct MapPinData: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let status: String
    let date: Date
    let deviceModel: String?
    let plotId: UUID?
    
    init(id: UUID, coordinate: CLLocationCoordinate2D, status: String, date: Date, deviceModel: String? = nil, plotId: UUID? = nil) {
        self.id = id
        self.coordinate = coordinate
        self.status = status
        self.date = date
        self.deviceModel = deviceModel
        self.plotId = plotId
    }
    
    var pinColor: Color {
        switch status {
        case "enfermo": return .red
        case "sospecha": return .orange
        case "sano": return .green
        default: return .gray
        }
    }
}
