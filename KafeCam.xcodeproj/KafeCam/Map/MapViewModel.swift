//
//  MapModel.swift
//  KafeCam
//
//  Created by Guillermo Lira on 01/10/25.
//

import Foundation
import MapKit
import CoreLocation

// Pin con metadatos
struct MapPlotPin: Identifiable, Equatable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D
    var name: String
    var status: PlotStatus
    var plantedAt: Date?

    init(id: UUID = UUID(),
         coordinate: CLLocationCoordinate2D,
         name: String = "Plantío",
         status: PlotStatus = .sano,
         plantedAt: Date? = nil) {
        self.id = id
        self.coordinate = coordinate
        self.name = name
        self.status = status
        self.plantedAt = plantedAt
    }

    static func == (lhs: MapPlotPin, rhs: MapPlotPin) -> Bool { lhs.id == rhs.id }
}

final class PlotsMapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    // Coordenada base (Chiapas)
    let baseCoordinate = CLLocationCoordinate2D(latitude: 15.7846022, longitude: -92.7611756)

    // Región visible
    @Published var region: MKCoordinateRegion

    // Pines y selección para sheet
    @Published var pins: [MapPlotPin] = [] {
        didSet {
            savePins()
        }
    }
    @Published var selectedPin: MapPlotPin?

    // Ubicación del usuario
    @Published var userCoordinate: CLLocationCoordinate2D?

    // Modo: esperando toque para colocar pin manual
    @Published var isAddingPin = false

    private var manager: CLLocationManager?
    private var pinCreateObserver: NSObjectProtocol?
    private let pinsStorageKey = "kafe.map.pins"

    override init() {
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 15.7846022, longitude: -92.7611756),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )
        super.init()
        startLocation()
        
        // Load persisted pins first
        loadPins()
        
        // Add base pin if no pins exist
        if pins.isEmpty {
            pins.append(MapPlotPin(coordinate: baseCoordinate, name: "Base"))
        }

        // Escuchar creación automática de pines (desde Detecta)
        pinCreateObserver = NotificationCenter.default.addObserver(
            forName: .kafeCreatePin,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let userInfo = note.userInfo ?? [:]

            // 1) Si viene "estado" directo, úsalo
            if let estadoStr = userInfo["estado"] as? String {
                let status = Self.status(from: estadoStr)
                self.handleAutoPin(status: status)
                return
            }

            // 2) Respaldo por porcentaje
            if let prob = userInfo["probabilidad"] as? Double {
                self.handleAutoPin(probabilidad: prob)
            }
        }
    }

    deinit {
        if let obs = pinCreateObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Location
    private func startLocation() {
        let m = CLLocationManager()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyBest

        switch m.authorizationStatus {
        case .notDetermined:
            m.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            m.startUpdatingLocation()
            m.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
        self.manager = m
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorization(manager.authorizationStatus, manager: manager)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorization(status, manager: manager)
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus, manager: CLLocationManager) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async { self.userCoordinate = latest.coordinate }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    // MARK: - Acciones de mapa / pines (manual)
    func addPin(at coordinate: CLLocationCoordinate2D) {
        let newPin = MapPlotPin(coordinate: coordinate, name: "Plantío \(pins.count + 1)")
        pins.append(newPin)
        selectedPin = newPin
        isAddingPin = false
    }

    func updatePin(_ pin: MapPlotPin) {
        if let idx = pins.firstIndex(where: { $0.id == pin.id }) {
            pins[idx] = pin
        }
    }

    func removePin(_ pin: MapPlotPin) {
        pins.removeAll { $0.id == pin.id }
        if selectedPin?.id == pin.id { selectedPin = nil }
    }

    func resetToBase() {
        region = MKCoordinateRegion(center: baseCoordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35))
    }

    func goToUser() {
        guard let u = userCoordinate else { return }
        region = MKCoordinateRegion(center: u,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    }

    func goToPin(_ pin: MapPlotPin) {
        region = MKCoordinateRegion(center: pin.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        selectedPin = pin
    }

    // MARK: - Crear pin automático desde Detecta (por estado directo)
    private func handleAutoPin(status: PlotStatus) {
        guard let coord = userCoordinate else {
            NotificationCenter.default.post(name: .kafePinAddFailedNoLocation, object: nil)
            return
        }

        let newPin = MapPlotPin(
            coordinate: coord,
            name: "Plantío \(pins.count + 1)",
            status: status,
            plantedAt: Date()
        )
        pins.append(newPin)

        // (Opcional) Enfocar región al nuevo pin:
        // region = MKCoordinateRegion(center: coord, span: .init(latitudeDelta: 0.03, longitudeDelta: 0.03))

        NotificationCenter.default.post(name: .kafePinAdded, object: nil)
    }

    // MARK: - Crear pin automático por porcentaje (respaldo)
    private func handleAutoPin(probabilidad: Double) {
        let status: PlotStatus
        switch probabilidad {
        case 70...100: status = .enfermo
        case 40..<70:  status = .sospecha
        default:       status = .sano
        }
        handleAutoPin(status: status)
    }

    // MARK: - Mapear string a PlotStatus
    private static func status(from raw: String) -> PlotStatus {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "enfermo", "enfermedad", "sick", "diseased":
            return .enfermo
        case "sospecha", "suspected", "sospechoso":
            return .sospecha
        case "sano", "sana", "healthy":
            return .sano
        default:
            return .sospecha
        }
    }
    
    // MARK: - Persistence
    private func savePins() {
        let pinData = pins.map { pin in
            [
                "id": pin.id.uuidString,
                "lat": pin.coordinate.latitude,
                "lon": pin.coordinate.longitude,
                "name": pin.name,
                "status": pin.status.rawValue,
                "plantedAt": pin.plantedAt?.timeIntervalSince1970 ?? 0
            ] as [String: Any]
        }
        UserDefaults.standard.set(pinData, forKey: pinsStorageKey)
    }
    
    private func loadPins() {
        guard let pinData = UserDefaults.standard.array(forKey: pinsStorageKey) as? [[String: Any]] else { return }
        
        pins = pinData.compactMap { data in
            guard let idStr = data["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let lat = data["lat"] as? Double,
                  let lon = data["lon"] as? Double,
                  let name = data["name"] as? String,
                  let statusStr = data["status"] as? String,
                  let status = PlotStatus(rawValue: statusStr) else { return nil }
            
            let plantedAt: Date? = {
                if let timestamp = data["plantedAt"] as? TimeInterval, timestamp > 0 {
                    return Date(timeIntervalSince1970: timestamp)
                }
                return nil
            }()
            
            return MapPlotPin(
                id: id,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                name: name,
                status: status,
                plantedAt: plantedAt
            )
        }
    }
}

import Foundation

extension Notification.Name {
    static let kafeCreatePin = Notification.Name("kafeCreatePin")
    static let kafePinAdded = Notification.Name("kafePinAdded")
    static let kafePinAddFailedNoLocation = Notification.Name("kafePinAddFailedNoLocation")
}
