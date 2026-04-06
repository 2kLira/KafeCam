//
//  DetectaView.swift
//  KafeCam
//

import SwiftUI
import CoreML
import Vision
import CoreLocation

struct DetectaView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var historyStore: HistoryStore
    @StateObject private var locationManager = SimpleLocationManager()
    
    @State private var prediction: String = ""
    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var takePhotoTrigger = false
    @State private var showSaveOptions = false

    // Datos para el pin del mapa
    @State private var lastStatus: PlotStatus = .sano
    @State private var lastConfidencePct: Double = 0.0  // 0–100
    @State private var lastDiseaseName: String = ""     // p.ej. "roya", "manganeso"

    var body: some View {
        ZStack {
            if let image = capturedImage {
                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(12)

                    Text(prediction)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()

                    if showSaveOptions {
                        HStack(spacing: 40) {
                            Button("❌ Rechazar") {
                                capturedImage = nil
                                prediction = ""
                                showSaveOptions = false
                                showCamera = true
                            }
                            .foregroundColor(.red)

                            Button("✅ Aceptar") {
                                guard let image = capturedImage else { return }
                                
                                // Guardar local para feedback inmediato
                                historyStore.add(image: image, prediction: prediction)
                                showSaveOptions = false

                                // Subir a Supabase (si está disponible)
                                Task {
                                    #if canImport(Supabase)
                                    do {
                                        if let uid = try? await SupaAuthService.currentUserId() {
                                            _ = LocalCapturesStore.shared.save(image: image, for: uid.uuidString)
                                        }
                                        if let jpeg = image.jpegData(compressionQuality: 0.85) {
                                            let svc = CapturesService()
                                            let lat = locationManager.lastLocation?.coordinate.latitude
                                            let lon = locationManager.lastLocation?.coordinate.longitude
                                            
                                            let capture = try await svc.saveCaptureToDefaultPlot(
                                                imageData: jpeg,
                                                takenAt: Date(),
                                                deviceModel: prediction.isEmpty ? "Foto" : prediction,
                                                lat: lat,
                                                lon: lon
                                            )
                                            print("[Detecta] Capture saved: \(capture.photoKey)")
                                            if let lat, let lon { print("[Detecta] Location: \(lat), \(lon)") }
                                            await historyStore.syncFromSupabase()
                                        }
                                    } catch {
                                        print("[Detecta] Error saving capture: \(error)")
                                    }
                                    #endif
                                }

                                // Notificar al mapa para crear pin
                                NotificationCenter.default.post(
                                    name: .kafeCreatePin,
                                    object: nil,
                                    userInfo: [
                                        "estado": lastStatus.rawValue.lowercased(),
                                        "probabilidad": lastConfidencePct,
                                        "label": lastDiseaseName,
                                        "fecha": Date()
                                    ]
                                )

                                // Volver al Home
                                dismiss()
                            }
                            .foregroundColor(.green)
                        }
                    }
                }
                .padding()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ZStack {
                // Vista de cámara
                CameraPreview(takePhotoTrigger: $takePhotoTrigger) { image in
                    self.capturedImage = image
                    self.classify(image: image)
                    self.showCamera = false
                    self.showSaveOptions = true
                }
                .ignoresSafeArea()

                // Controles
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                                .padding(.leading, 20)
                                .padding(.top, 20)
                        }
                        Spacer()
                    }

                    Spacer()

                    Button(action: { takePhotoTrigger = true }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 80, height: 80)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Clasificación con CoreML
    func classify(image: UIImage) {
        let config = MLModelConfiguration()

        // 1) Cargar el modelo (clase generada o .mlmodelc en bundle)
        let vnModel: VNCoreMLModel
        do {
            if let compiledURL = Bundle.main.url(forResource: "KafeCamFinal", withExtension: "mlmodelc") {
                // Cambia "KafeCamFinal" si tu .mlmodelc tiene otro nombre (sin espacios)
                let coreML = try MLModel(contentsOf: compiledURL, configuration: config)
                vnModel = try VNCoreMLModel(for: coreML)
            } else {
                // Clase generada por Xcode a partir de KafeCamFinal.mlmodel
                vnModel = try VNCoreMLModel(for: KafeCamFinal(configuration: config).model)
            }
        } catch {
            prediction = "⚠️ Error al cargar modelo: \(error.localizedDescription)"
            return
        }

        // 2) Request (sin [weak self]; DetectaView es struct)
        let request = VNCoreMLRequest(model: vnModel) { req, _ in
            if let result = req.results?.first as? VNClassificationObservation {
                let label = result.identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let confidence = Double(result.confidence * 100.0)

                let parsed = parseStatus(from: label)
                let status = parsed.status
                let diseaseName = parsed.diseaseName

                DispatchQueue.main.async {
                    self.lastStatus = status
                    self.lastConfidencePct = confidence
                    self.lastDiseaseName = diseaseName

                    switch status {
                    case .sano:
                        self.prediction = "🌿 Planta sana (\(Int(confidence))%)"
                    case .sospecha:
                        self.prediction = diseaseName.isEmpty
                            ? "⚠️ Sospecha (\(Int(confidence))%)"
                            : "⚠️ Sospecha de \(diseaseName.capitalized) (\(Int(confidence))%)"
                    case .enfermo:
                        self.prediction = diseaseName.isEmpty
                            ? "🚨 Enfermo (\(Int(confidence))%)"
                            : "🚨 \(diseaseName.capitalized) (\(Int(confidence))%)"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.prediction = "⚠️ No se pudo clasificar la imagen"
                }
            }
        }

        // 3) Handler
        guard let ciImage = CIImage(image: image) else {
            prediction = "⚠️ Imagen inválida"
            return
        }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.prediction = "⚠️ Error al procesar la imagen"
                }
            }
        }
    }

    // MARK: - Parser de label → (status, diseaseName)
    private func parseStatus(from raw: String) -> (status: PlotStatus, diseaseName: String) {
        // Casos: "sana/sano", "<enfermedad> sospecha", "<enfermedad> enfermo"
        let parts = raw.split(separator: " ").map { String($0) }

        if parts.count == 1 {
            let word = parts[0]
            if word == "sana" || word == "sano" || word == "saludable" || word == "healthy" {
                return (.sano, "")
            }
            return (.sospecha, word)
        } else {
            let disease = parts.dropLast().joined(separator: " ")
            let state = parts.last ?? ""
            switch state {
            case "sospecha", "sospechoso", "suspected":
                return (.sospecha, disease)
            case "enfermo", "enfermedad", "diseased", "sick":
                return (.enfermo, disease)
            case "sano", "sana", "healthy":
                return (.sano, disease)
            default:
                return (.sospecha, disease)
            }
        }
    }
}

#Preview {
    DetectaView()
        .environmentObject(HistoryStore())
}

// MARK: - Simple Location Manager
class SimpleLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    func requestFreshLocation() {
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
            locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
        print("[LocationManager] Location updated: \(lastLocation?.coordinate.latitude ?? 0), \(lastLocation?.coordinate.longitude ?? 0)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationManager] Error: \(error.localizedDescription)")
    }
}
