import SwiftUI
import CoreML
import Vision
import CoreLocation

private enum MLModelCache {
    static let vnModel: VNCoreMLModel? = {
        let config = MLModelConfiguration()
        if let compiledURL = Bundle.main.url(forResource: "CoffeeDiseaseClassifier_v10", withExtension: "mlmodelc"),
           let coreML = try? MLModel(contentsOf: compiledURL, configuration: config) {
            return try? VNCoreMLModel(for: coreML)
        }
        return try? VNCoreMLModel(for: CoffeeDiseaseClassifier_v100(configuration: config).model)
    }()
}

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

    @State private var lastStatus: PlotStatus = .sano
    @State private var lastConfidencePct: Double = 0.0
    @State private var lastDiseaseName: String = ""
    @State private var isNoPlantDetected: Bool = false
    @State private var captureError: String? = nil
    @State private var showCameraDeniedAlert = false

    private var assistantQuestion: String {
        let name = lastDiseaseName.isEmpty ? "una posible enfermedad" : lastDiseaseName
        return "Detecté \(name) en una foto de mi cafetal. ¿Qué me recomiendas?"
    }

    var body: some View {
        ZStack {
            if let image = capturedImage {
                ScrollView {
                    VStack(spacing: 20) {
                        // Captured photo
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous))
                            .padding(.horizontal)

                        if isAnalyzing {
                            AnalyzingCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                        }

                        if showSaveOptions && !isAnalyzing {
                            if isNoPlantDetected {
                                NoPlantCard {
                                    capturedImage = nil
                                    prediction = ""
                                    showSaveOptions = false
                                    isNoPlantDetected = false
                                    showCamera = true
                                }
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else {
                                // Diagnosis result card
                                DiagnosisResultCard(
                                    status: lastStatus,
                                    diseaseName: lastDiseaseName,
                                    confidence: lastConfidencePct
                                )
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))

                                // Advice card — what to do next
                                if let advice = adviceForCurrentDiagnosis() {
                                    AdviceCard(advice: advice)
                                        .padding(.horizontal)
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }

                                // Accept / Reject actions
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        // Reject — resets to camera
                                        Button {
                                            capturedImage = nil
                                            prediction = ""
                                            showSaveOptions = false
                                            isAnalyzing = false
                                            isNoPlantDetected = false
                                            showCamera = true
                                        } label: {
                                            Label("Rechazar", systemImage: "arrow.counterclockwise")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.primary)
                                        .controlSize(.large)

                                        // Accept — saves capture (logic preserved exactly)
                                        Button {
                                            guard let image = capturedImage else { return }
                                            historyStore.add(image: image, prediction: prediction)
                                            showSaveOptions = false
                                            Task {
                                                let takenAt = Date()
                                                let lat = locationManager.lastLocation?.coordinate.latitude
                                                let lon = locationManager.lastLocation?.coordinate.longitude
                                                let predText = prediction.isEmpty ? "Foto" : prediction
                                                CrashMonitor.breadcrumb("Captura aceptada: \(predText)", category: "detecta")

                                                #if canImport(Supabase)
                                                let uid = (try? await SupaAuthService.currentUserId()) ?? UUID()
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

                                                #if canImport(Supabase)
                                                guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
                                                do {
                                                    let svc = CapturesService()
                                                    let diagInput = DiagnosisInput.from(
                                                        diseaseName: lastDiseaseName,
                                                        status: lastStatus,
                                                        confidencePct: lastConfidencePct
                                                    )
                                                    _ = try await svc.saveCaptureToDefaultPlot(
                                                        imageData: jpeg,
                                                        takenAt: takenAt,
                                                        deviceModel: predText,
                                                        lat: lat,
                                                        lon: lon,
                                                        clientUUID: clientId,
                                                        diagnosis: diagInput
                                                    )
                                                    store.markSynced(id: clientId)
                                                    debugLog("[Detecta] Capture synced immediately")
                                                    await historyStore.syncFromSupabase()
                                                    if FeatureFlags.assignmentsEnabled {
                                                        await PushNotificationService.shared.notifyTechnicianCaptureSaved(
                                                            captureId: clientId,
                                                            prediction: predText
                                                        )
                                                    }
                                                } catch {
                                                    debugLog("[Detecta] Sin red – capture en cola: \(error)")
                                                    OfflineSyncService.shared.refreshPendingCount(for: uid.uuidString)
                                                }
                                                #endif
                                            }

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
                                        } label: {
                                            Label("Aceptar", systemImage: "checkmark")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(AppTheme.accent)
                                        .controlSize(.large)
                                    }

                                    Button {
                                        showAsistente = true
                                    } label: {
                                        Label("Preguntar al asistente",
                                              systemImage: "bubble.left.and.exclamationmark.bubble.right.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(AppTheme.dark)
                                }
                                .padding(.horizontal)
                                .transition(.opacity)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 16)
                }
                .animation(.easeOut(duration: AppTheme.animNormal), value: isAnalyzing)
                .animation(.easeOut(duration: AppTheme.animNormal), value: showSaveOptions)
            }
        }
        .sheet(isPresented: $showAsistente) {
            NavigationStack {
                AsistenteView(initialQuestion: assistantQuestion)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ZStack {
                CameraPreview(takePhotoTrigger: $takePhotoTrigger, onPhotoCaptured: { image in
                    self.capturedImage = image
                    self.prediction = ""
                    self.isAnalyzing = true
                    self.showCamera = false
                    self.showSaveOptions = false
                    self.isNoPlantDetected = false
                    self.classify(image: image)
                }, onError: { message in
                    self.takePhotoTrigger = false
                    if message == "camera_denied" {
                        self.showCameraDeniedAlert = true
                    } else {
                        self.captureError = message
                    }
                })
                .ignoresSafeArea()
                .alert("Cámara", isPresented: Binding(
                    get: { captureError != nil },
                    set: { if !$0 { captureError = nil } }
                )) {
                    Button("OK", role: .cancel) { captureError = nil }
                } message: {
                    Text(captureError ?? "")
                }

                // Camera UI overlay
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }
                        .frame(width: AppTheme.minTouchTarget, height: AppTheme.minTouchTarget)
                        .contentShape(Rectangle())
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        .accessibilityLabel("Volver")

                        Spacer()
                    }

                    Spacer()

                    // Shutter button
                    Button(action: { takePhotoTrigger = true }) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 76, height: 76)
                            Circle()
                                .strokeBorder(.white.opacity(0.6), lineWidth: 4)
                                .frame(width: 88, height: 88)
                        }
                    }
                    .buttonStyle(KafeCardPressStyle())
                    .accessibilityLabel("Capturar foto")
                    .padding(.bottom, 48)
                }
            }
            .onAppear {
                DispatchQueue.global(qos: .userInitiated).async { _ = MLModelCache.vnModel }
            }
            .alert("Acceso a la cámara", isPresented: $showCameraDeniedAlert) {
                Button("Ahora no", role: .cancel) { showCamera = false }
                Button("Ir a Configuración") {
                    showCamera = false
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Para usar Detecta, permite el acceso a la cámara en Configuración.")
            }
        }
    }

    // MARK: - CoreML Classification
    func classify(image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let vnModel = MLModelCache.vnModel else {
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.prediction = "Modelo no disponible. Intenta de nuevo."
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
                            self.prediction = "No se detectó una hoja de café"
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
                DispatchQueue.main.async {
                    self.prediction = "Imagen inválida"
                    self.isAnalyzing = false
                    self.showSaveOptions = true
                }
                return
            }

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                CrashMonitor.capture(error, context: [
                    "model": "CoffeeDiseaseClassifier_v10",
                    "phase": "inference"
                ])
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.prediction = "Error al procesar la imagen"
                    self.showSaveOptions = true
                }
            }
        }
    }

    // MARK: - Parser del label del modelo (unchanged)
    private func parseStatus(from raw: String, confidence: Double) -> (status: PlotStatus, diseaseName: String) {
        let label = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch label {
        case "sana", "sano", "saludable", "healthy":
            return (.sano, "")
        case "no_planta", "no planta", "noplanta":
            return (.sospecha, "no_planta")
        case "roya":
            return (confidence >= 70 ? .enfermo : .sospecha, "roya")
        case "minador":
            return (confidence >= 70 ? .enfermo : .sospecha, "minador")
        case "phoma":
            return (confidence >= 70 ? .enfermo : .sospecha, "phoma")
        case "brown_eye":
            return (confidence >= 70 ? .enfermo : .sospecha, "BROWN_EYE")
        case "white_eye":
            return (confidence >= 70 ? .enfermo : .sospecha, "WHITE_EYE")
        default:
            return (.sospecha, label)
        }
    }

    // MARK: - Advice for current diagnosis

    // Declared as fileprivate so AdviceCard (outside DetectaView) can reference it.
    fileprivate struct DiseaseAdvice {
        let icon: String
        let tint: Color
        let title: String
        let text: String
    }

    private static let adviceMap: [String: DiseaseAdvice] = [
        "roya": DiseaseAdvice(
            icon: "exclamationmark.triangle.fill", tint: .orange,
            title: "Qué hacer con la Roya",
            text: "Retira hojas con polvo naranja. Si la incidencia supera el 5%, aplica fungicida cúprico. Evita mojar el follaje. Consulta a tu técnico antes de cualquier tratamiento."
        ),
        "minador": DiseaseAdvice(
            icon: "ant.fill", tint: Color(red: 0.7, green: 0.5, blue: 0.0),
            title: "Qué hacer con el Minador",
            text: "Elimina hojas con galerías visibles. Favorece los enemigos naturales evitando insecticidas de amplio espectro. Control biológico efectivo en etapas tempranas."
        ),
        "phoma": DiseaseAdvice(
            icon: "drop.triangle.fill", tint: .red,
            title: "Qué hacer con Phoma",
            text: "Mejora el drenaje y la aireación del cafetal. Retira frutos y hojas afectados. Aplica fungicida solo si la incidencia es alta. Consulta a tu técnico."
        ),
        "sano": DiseaseAdvice(
            icon: "checkmark.seal.fill", tint: .green,
            title: "Planta en buen estado",
            text: "Tu cafetal luce saludable. Continúa con las labores culturales de rutina: deshije, poda, fertilización según el ciclo. Monitorea semanalmente."
        ),
        "BROWN_EYE": DiseaseAdvice(
            icon: "eye.trianglebadge.exclamationmark.fill", tint: Color(red: 0.55, green: 0.35, blue: 0.15),
            title: "Mancha de ojo café",
            text: "Cercospora coffeicola. Mejora la nutrición (especialmente zinc y boro). Retira hojas con manchas. Aplica fungicida si la incidencia supera el 10%."
        ),
        "WHITE_EYE": DiseaseAdvice(
            icon: "eye.fill", tint: Color(red: 0.4, green: 0.5, blue: 0.6),
            title: "Mancha de ojo blanco",
            text: "Lesiones circulares con centro pálido. Mejora el drenaje y reduce la humedad. Retira hojas afectadas. Monitorea la propagación semanalmente."
        )
    ]

    private func adviceForCurrentDiagnosis() -> DiseaseAdvice? {
        guard let code = DiagnosisInput.from(
            diseaseName: lastDiseaseName,
            status: lastStatus,
            confidencePct: lastConfidencePct
        )?.diseaseCode else { return nil }
        return Self.adviceMap[code]
    }

    // MARK: - Display name for classify() (unchanged)
    private func displayName(for disease: String) -> String {
        switch disease.lowercased() {
        case "roya":       return "Roya del café"
        case "minador":    return "Minador de la hoja"
        case "phoma":      return "Phoma (mancha de hierro)"
        case "brown_eye":  return "Mancha de ojo café"
        case "white_eye":  return "Mancha de ojo blanco"
        case "no_planta":  return "Sin planta detectada"
        default:           return disease.capitalized
        }
    }
}

// MARK: - Analyzing Card

private struct AnalyzingCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Analizando la hoja...")
                    .font(.subheadline.weight(.medium))
                Text("Esto tarda unos segundos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - No Plant Detected Card

private struct NoPlantCard: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No se detectó una hoja de café")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Acerca la cámara directamente a una hoja de café e intenta de nuevo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onRetry()
            } label: {
                Label("Volver a capturar", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.dark)
            .controlSize(.large)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Diagnosis Result Card

private struct DiagnosisResultCard: View {
    let status: PlotStatus
    let diseaseName: String
    let confidence: Double

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: statusIcon)
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(statusColor)

            VStack(spacing: 6) {
                Text(statusTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                if !diseaseName.isEmpty && diseaseName != "no_planta" {
                    Text(formattedDiseaseName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("\(Int(confidence))% de confianza")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.12))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .fill(statusColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                        .stroke(statusColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var statusColor: Color {
        switch status {
        case .sano:     return AppTheme.statusHealthy
        case .sospecha: return AppTheme.statusSuspect
        case .enfermo:  return AppTheme.statusSick
        }
    }

    private var statusIcon: String {
        switch status {
        case .sano:     return "checkmark.circle.fill"
        case .sospecha: return "exclamationmark.circle.fill"
        case .enfermo:  return "xmark.octagon.fill"
        }
    }

    private var statusTitle: String {
        switch status {
        case .sano:     return "Hoja sana"
        case .sospecha: return "Posible problema"
        case .enfermo:  return "Enfermedad detectada"
        }
    }

    private var formattedDiseaseName: String {
        switch diseaseName.lowercased() {
        case "roya":    return "Roya del café"
        case "minador": return "Minador de la hoja"
        case "phoma":   return "Phoma (mancha de hierro)"
        default:        return diseaseName.capitalized
        }
    }
}

// MARK: - Advice Card

private struct AdviceCard: View {
    let advice: DetectaView.DiseaseAdvice

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: advice.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(advice.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(advice.title)
                    .font(.subheadline.weight(.semibold))
                Text(advice.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .fill(advice.tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                        .stroke(advice.tint.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    DetectaView()
        .environmentObject(HistoryStore())
}

// MARK: - Simple Location Manager (unchanged)
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
