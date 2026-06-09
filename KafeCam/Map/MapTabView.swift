import SwiftUI
import MapKit
import Combine

struct MapTabView: View {
    @EnvironmentObject var vm: PlotsMapViewModel

    @State private var showHint = false
    @State private var hintText = "Pin agregado"
    @State private var hintIcon = "mappin.circle.fill"
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 15.7846022, longitude: -92.7611756),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // Map with user location and pins
                    Map(position: $cameraPosition) {
                        ForEach(vm.pins) { pin in
                            Annotation("", coordinate: pin.coordinate) {
                                Button { vm.selectedPin = pin } label: {
                                    Image(systemName: "leaf.fill")
                                        .foregroundStyle(pinColor(for: pin.status))
                                        .padding(7)
                                        .background(.white, in: Circle())
                                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                }
                                .accessibilityLabel("Pin: \(pin.name)")
                            }
                        }
                        UserAnnotation()
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                    .ignoresSafeArea()
                    .onAppear {
                        cameraPosition = .region(vm.region)
                        currentRegion = vm.region
                    }
                    .onReceive(vm.$region) { newRegion in
                        withAnimation(.easeOut(duration: 0.4)) {
                            cameraPosition = .region(newRegion)
                        }
                        currentRegion = newRegion
                    }
                    .onMapCameraChange { ctx in
                        currentRegion = ctx.region
                    }

                    // Tap overlay for manual pin placement
                    if vm.isAddingPin {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        guard vm.isAddingPin else { return }
                                        let coord = toCoordinate(
                                            point: value.location,
                                            in: geo.size,
                                            region: currentRegion
                                        )
                                        vm.addPin(at: coord)
                                        showTemporaryHint("Pin agregado", icon: "mappin.circle.fill")
                                    }
                            )
                    }

                    // Floating action buttons (right side)
                    VStack {
                        Spacer()
                        VStack(spacing: 12) {
                            // Toggle add-pin mode
                            Button {
                                vm.isAddingPin.toggle()
                            } label: {
                                mapButton(
                                    icon: vm.isAddingPin ? "xmark" : "mappin.and.ellipse",
                                    color: vm.isAddingPin ? AppTheme.dark : AppTheme.accent
                                )
                            }
                            .accessibilityLabel(vm.isAddingPin ? "Cancelar" : "Agregar pin")

                            // Go to base region
                            Button { vm.resetToBase() } label: {
                                mapButton(icon: "house.fill", color: AppTheme.dark)
                            }
                            .accessibilityLabel("Vista inicial")

                            // Go to user location
                            Button { vm.goToUser() } label: {
                                mapButton(icon: "location.fill", color: AppTheme.accent)
                            }
                            .accessibilityLabel("Mi ubicación")

                            // Go to each pin
                            ForEach(Array(vm.pins.enumerated()), id: \.1.id) { idx, pin in
                                Button { vm.goToPin(pin) } label: {
                                    mapButton(icon: "\(idx + 1).circle.fill", color: AppTheme.cardGreen2)
                                }
                                .accessibilityLabel("Pin \(idx + 1): \(pin.name)")
                            }
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .zIndex(2)

                    // Toast hint (success / error)
                    if showHint {
                        VStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: hintIcon)
                                    .foregroundStyle(AppTheme.accent)
                                Text(hintText)
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            .padding(.bottom, 70)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(3)
                    }

                    // Add-pin instruction banner
                    if vm.isAddingPin {
                        VStack {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.tap.fill")
                                    .foregroundStyle(AppTheme.accent)
                                Text("Toca el mapa para colocar el pin")
                                    .font(.callout.weight(.semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.top, 12)
                            Spacer()
                        }
                        .transition(.opacity)
                        .zIndex(3)
                    }
                }
            }
            .navigationTitle("Mapa")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $vm.selectedPin) { pin in
                PinDetailSheet(
                    pin: binding(for: pin),
                    onSave: { vm.updatePin($0) },
                    onDelete: { vm.removePin($0) }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .kafePinAdded)) { _ in
                showTemporaryHint("Pin agregado automáticamente", icon: "mappin.circle.fill")
            }
            .onReceive(NotificationCenter.default.publisher(for: .kafePinAddFailedNoLocation)) { _ in
                showTemporaryHint("No se pudo obtener tu ubicación", icon: "location.slash.fill")
            }
        }
    }

    // MARK: - Binding to pin in array
    private func binding(for pin: MapPlotPin) -> Binding<MapPlotPin> {
        if let idx = vm.pins.firstIndex(where: { $0.id == pin.id }) {
            return $vm.pins[idx]
        }
        DispatchQueue.main.async { vm.selectedPin = nil }
        return .constant(pin)
    }

    // MARK: - Map button helper
    private func mapButton(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: AppTheme.minTouchTarget, height: AppTheme.minTouchTarget)
            .background(color, in: Circle())
            .shadow(color: color.opacity(0.35), radius: 4, y: 2)
    }

    private func pinColor(for status: PlotStatus) -> Color {
        switch status {
        case .sano:     return AppTheme.statusHealthy
        case .sospecha: return AppTheme.statusSuspect
        case .enfermo:  return AppTheme.statusSick
        }
    }

    private func showTemporaryHint(_ text: String, icon: String = "checkmark.circle.fill") {
        hintText = text
        hintIcon = icon
        withAnimation { showHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { showHint = false }
        }
    }

    private func toCoordinate(point: CGPoint, in size: CGSize, region: MKCoordinateRegion) -> CLLocationCoordinate2D {
        let latDelta = region.span.latitudeDelta
        let lonDelta = region.span.longitudeDelta
        let dx = (point.x - size.width  / 2.0) / size.width
        let dy = (size.height / 2.0 - point.y) / size.height
        let lat = region.center.latitude  + Double(dy) * latDelta
        let lon = region.center.longitude + Double(dx) * lonDelta
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Pin Detail Sheet
struct PinDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var pin: MapPlotPin
    var onSave: (MapPlotPin) -> Void
    var onDelete: (MapPlotPin) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Nombre del plantío", text: $pin.name)

                    Picker("Estatus", selection: $pin.status) {
                        ForEach(PlotStatus.allCases) { st in
                            Text(st.rawValue).tag(st)
                        }
                    }

                    DatePicker(
                        "Fecha de plantación",
                        selection: $pin.plantedAt.unwrap(Date()),
                        displayedComponents: .date
                    )
                }

                Section {
                    Button(role: .destructive) {
                        onDelete(pin)
                        dismiss()
                    } label: {
                        Label("Eliminar pin", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Plantío")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(pin)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Binding<Optional> helper
extension Binding {
    func unwrap<T>(_ defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
