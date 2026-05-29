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
    @State private var showAsistente = false

    // Datos para el pin del mapa
    @State private var lastStatus: PlotStatus = .sano
    @State private var lastConfidencePct: Double = 0.0
    @State private var lastDiseaseName: String = ""
    // true cuando el modelo detecta que la foto no contiene una planta de café
    @State private var isNoPlantDetected: Bool = false

    // Pregunta con la que se abre el asistente tras el diagnóstico.
    private var assistantQuestion: String {
        let name = lastDiseaseName.isEmpty ? "una posible enfermedad" : lastDiseaseName
        return "Detecté \(name) en una foto de mi cafetal. ¿Qué me recomiendas?"
    }

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
                        if isNoPlantDetected {
                            // ── No se detectó planta ──────────────────────────
                            VStack(spacing: 12) {
                                Text("Acerca la cámara directamente a una hoja de café e intenta de nuevo.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                Button("🔄 Volver a capturar") {
                                    capturedImage = nil
                                    prediction = ""
                                    showSaveOptions = false
                                    isNoPlantDetected = false
                                    showCamera = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.brown)
                            }
                        } else {
                        // ── Diagnóstico válido ────────────────────────────────
                        HStack(spacing: 40) {
                            Button("❌ Rechazar") {
                                capturedImage = nil
                                prediction = ""
                                showSaveOptions = false
                                isAnalyzing = false
                                isNoPlantDetected = false
                                showCamera = true
                            }
                            .foregroundColor(.red)

                            Button("✅ Aceptar") {
                                guard let image = capturedImage else { return }

                                historyStore.add(image: image, prediction: prediction)
                                showSaveOptions = false

                                Task {
                                    let takenAt = Date()
                                    let lat = locationManager.lastLocation?.coordinate.latitude
                                    let lon = locationManager.lastLocation?.coordinate.longitude
                                    let predText = prediction.isEmpty ? "Foto" : prediction
                                    CrashMonitor.breadcrumb("Captura aceptada: \(predText)", category: "detecta")

                                    // 1. Siempre persistir en disco primero (funciona sin red)
                                    #if canImport(Supabase)
                                    guard let uid = try? await SupaAuthService.currentUserId() else { return }
                                    #else
                                    let uid = UUID()
                                    #endif
                                    let clientId = UUID()
                                    let store = PendingCaptureStore.shared
                                    let fileName = store.saveImage(image, userId: uid.uuidString) ?? ""
                                    let pending = PendingCapture(
                                        id: clientId,
                                        userId: uid.uuidString,
                                        clientUUID: clientId,
                                        imageFileName: fileName,
                                        prediction: predText,
                                        diseaseName: lastDiseaseName,
                                        statusRaw: lastStatus.rawValue,
                                        confidencePct: lastConfidencePct,
                                        lat: lat,
                                        lon: lon,
                                        takenAt: takenAt,
                                        syncedAt: nil
                                    )
                                    store.queue(pending)

                                    // 2. Intentar subir a Supabase; si falla, OfflineSyncService lo reintentará
                                    #if canImport(Supabase)
                                    guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
                                    do {
                                        let svc = CapturesService()
                                        _ = try await svc.saveCaptureToDefaultPlot(
                                            imageData: jpeg,
                                            takenAt: takenAt,
                                            deviceModel: predText,
                                            lat: lat,
                                            lon: lon
                                        )
                                        store.markSynced(id: clientId)
                                        debugLog("[Detecta] Capture synced immediately")
                                        await historyStore.syncFromSupabase()
                                        // Notificación al técnico: gated (v2). La Edge Function
                                        // `notify-technician` no está desplegada y no hay técnico
                                        // asignado mientras el flujo de asignación esté apagado.
                                        if FeatureFlags.assignmentsEnabled {
                                            await PushNotificationService.shared.notifyTechnicianCaptureSaved(
                                                captureId: clientId,
                                                prediction: predText
                                            )
                                        }
                                    } catch {
                                        debugLog("[Detecta] Sin red – capture en cola: \(error)")
                                        OfflineSyncService.shared.refreshPendingCount(for: uid.uuidString)
                                        // Error de red esperado — no enviar a Sentry (se reintentará)
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

                        Button {
                            showAsistente = true
                        } label: {
                            Label("Preguntar al asistente", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        } // end else (diagnóstico válido)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAsistente) {
            NavigationStack {
                AsistenteView(initialQuestion: assistantQuestion)
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
                    self.isNoPlantDetected = false
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
                vnModel = try VNCoreMLModel(for: CoffeeDiseaseClassifier_v100(configuration: config).model)
            }
        } catch {
            CrashMonitor.capture(error, context: [
                "model": "CoffeeDiseaseClassifier_v10",
                "phase": "load"
            ])
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
                let isNoPlant = label == "no_planta" || label == "no planta" || label == "noplanta"
                let parsed = self.parseStatus(from: label, confidence: confidence)
                let status = parsed.status
                let diseaseName = parsed.diseaseName
                let shownName = self.displayName(for: diseaseName)

                DispatchQueue.main.async {
                    self.isNoPlantDetected = isNoPlant

                    if isNoPlant {
                        self.prediction = "📷 No se detectó una hoja de café"
                        self.isAnalyzing = false
                        self.showSaveOptions = true
                        return
                    }

                    self.lastStatus = status
                    self.lastConfidencePct = confidence
                    self.lastDiseaseName = diseaseName

                    switch status {
                    case .sano:
                        self.prediction = "🌿 Hoja sana (\(Int(confidence))%)"

                    case .sospecha:
                        self.prediction = diseaseName.isEmpty
                            ? "⚠️ Posible problema (\(Int(confidence))%)"
                            : "⚠️ Posible \(shownName) (\(Int(confidence))%)"

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
                CrashMonitor.capture(error, context: [
                    "model": "CoffeeDiseaseClassifier_v10",
                    "phase": "inference"
                ])
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.prediction = "⚠️ Error al procesar la imagen"
                    self.showSaveOptions = true
                }
            }
        }
    }

    // MARK: - Parser del label del modelo
    private func parseStatus(from raw: String, confidence: Double) -> (status: PlotStatus, diseaseName: String) {
        let label = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch label {
        case "sana", "sano", "saludable", "healthy":
            return (.sano, "")

        case "no_planta", "no planta", "noplanta":
            return (.sospecha, "no_planta")

        case "roya":
            let status: PlotStatus = confidence >= 70 ? .enfermo : .sospecha
            return (status, "roya")

        case "minador":
            let status: PlotStatus = confidence >= 70 ? .enfermo : .sospecha
            return (status, "minador")

        case "phoma":
            let status: PlotStatus = confidence >= 70 ? .enfermo : .sospecha
            return (status, "phoma")

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
            return "Phoma (mancha de hierro)"
        case "no_planta":
            return "Sin planta detectada"
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
