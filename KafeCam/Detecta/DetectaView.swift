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
    @State private var isAnalyzing = false

    // Datos para el pin del mapa
    @State private var lastStatus: PlotStatus = .sano
    @State private var lastConfidencePct: Double = 0.0
    @State private var lastDiseaseName: String = ""

    var body: some View {
        ZStack {
            if let image = capturedImage {
                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(12)

                    if isAnalyzing {
                        ProgressView("Analizando hoja...")
                            .padding(.top, 8)
                    }

                    Text(prediction.isEmpty ? "Procesando resultado..." : prediction)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()

                    if showSaveOptions && !isAnalyzing {
                        HStack(spacing: 40) {
                            Button("❌ Rechazar") {
                                capturedImage = nil
                                prediction = ""
                                showSaveOptions = false
                                isAnalyzing = false
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

                                            debugLog("[Detecta] Capture saved: \(capture.photoKey)")
                                            if let lat, let lon {
                                                debugLog("[Detecta] Location: \(lat), \(lon)")
                                            }

                                            await historyStore.syncFromSupabase()
                                        }
                                    } catch {
                                        debugLog("[Detecta] Error saving capture: \(error)")
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
                CameraPreview(takePhotoTrigger: $takePhotoTrigger) { image in
                    self.capturedImage = image
                    self.prediction = ""
                    self.isAnalyzing = true
                    self.showCamera = false
                    self.showSaveOptions = false
                    self.classify(image: image)
                }
                .ignoresSafeArea()

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

        let vnModel: VNCoreMLModel
        do {
            if let compiledURL = Bundle.main.url(forResource: "CoffeeDiseaseClassifier_v10", withExtension: "mlmodelc") {
                let coreML = try MLModel(contentsOf: compiledURL, configuration: config)
                vnModel = try VNCoreMLModel(for: coreML)
            } else {
                vnModel = try VNCoreMLModel(for: CoffeeDiseaseClassifier_v10(configuration: config).model)
            }
        } catch {
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.prediction = "⚠️ Error al cargar el modelo: \(error.localizedDescription)"
                self.showSaveOptions = true
            }
            return
        }

        let request = VNCoreMLRequest(model: vnModel) { req, _ in
            if let result = req.results?.first as? VNClassificationObservation {
                let label = result.identifier
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                let confidence = Double(result.confidence * 100.0)
                let parsed = parseStatus(from: label)
                let status = parsed.status
                let diseaseName = parsed.diseaseName
                let shownName = displayName(for: diseaseName)

                DispatchQueue.main.async {
                    self.lastStatus = status
                    self.lastConfidencePct = confidence
                    self.lastDiseaseName = diseaseName

                    switch status {
                    case .sano:
                        self.prediction = "🌿 Hoja sana (\(Int(confidence))%)"

                    case .sospecha:
                        self.prediction = diseaseName.isEmpty
                            ? "⚠️ Sospecha (\(Int(confidence))%)"
                            : "⚠️ Sospecha de \(shownName) (\(Int(confidence))%)"

                    case .enfermo:
                        self.prediction = diseaseName.isEmpty
                            ? "🚨 Enfermedad detectada (\(Int(confidence))%)"
                            : "🚨 \(shownName) (\(Int(confidence))%)"
                    }

                    self.isAnalyzing = false
                    self.showSaveOptions = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.prediction = "⚠️ No se pudo clasificar la imagen"
                    self.showSaveOptions = true
                }
            }
        }

        request.imageCropAndScaleOption = .scaleFit
        
        guard let ciImage = CIImage(image: image) else {
            prediction = "⚠️ Imagen inválida"
            isAnalyzing = false
            showSaveOptions = true
            return
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.prediction = "⚠️ Error al procesar la imagen"
                    self.showSaveOptions = true
                }
            }
        }
    }

    // MARK: - Parser del label del modelo
    private func parseStatus(from raw: String) -> (status: PlotStatus, diseaseName: String) {
        let label = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch label {
        case "sana", "sano", "saludable", "healthy":
            return (.sano, "")

        case "roya":
            return (.enfermo, "roya")

        case "minador":
            return (.enfermo, "minador")

        case "phoma":
            return (.enfermo, "phoma")

        default:
            return (.sospecha, label)
        }
    }

    // MARK: - Nombre bonito para mostrar al usuario
    private func displayName(for disease: String) -> String {
        switch disease.lowercased() {
        case "roya":
            return "Roya del café"
        case "minador":
            return "Minador de la hoja"
        case "phoma":
            return "Phoma"
        default:
            return disease.capitalized
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
        debugLog("[LocationManager] Location updated: \(lastLocation?.coordinate.latitude ?? 0), \(lastLocation?.coordinate.longitude ?? 0)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugLog("[LocationManager] Error: \(error.localizedDescription)")
    }
}
