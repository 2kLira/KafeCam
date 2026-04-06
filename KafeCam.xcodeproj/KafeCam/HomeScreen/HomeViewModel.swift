//
//  HomeViewModel.swift
//  KafeCam
//
//  Created by Grecia Saucedo on 08/09/25.
//
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    // Entrada
    private let camera: CameraUsageService
    private let soil: SoilSensorService
    
    // Estado expuesto a la vista
    @Published var alerts: [AlertItem] = []
    @Published var greetingName: String = ""
    
    // Colores
    let accentColor  = Color(red: 88/255, green: 129/255, blue: 87/255)
    let darkColor    = Color(red: 82/255,  green: 76/255,  blue: 41/255)
    
    init(camera: CameraUsageService = MockCameraUsageService(),
         soil: SoilSensorService = MockSoilSensorService(),
         greetingName: String? = nil) {
        self.camera = camera
        self.soil   = soil
        if let name = greetingName, !name.isEmpty { self.greetingName = name }
    }
    
    func refresh() {
        var list: [AlertItem] = []
        
        let days = camera.daysSinceLastPhoto()
        if days >= 5 {
            list.append(.init(
                title: "Sin foto reciente",
                message: "Hace \(days) días que no tomas una foto. ¡Captura! 📸",
                level: .warning
            ))
        }
        
        let moisture = soil.soilMoisturePercent()
        if moisture < 25 {
            list.append(.init(
                title: "Humedad baja",
                message: "Humedad del suelo en \(moisture)%. Riega o revisa el riego.",
                level: .critical
            ))
        }
        
        let temp = soil.soilTempCelsius()
        if temp >= 28 {
            list.append(.init(
                title: "Temperatura alta",
                message: "El suelo llegó a \(temp)°C. Vigila el estrés.",
                level: .warning
            ))
        }
        
        if list.isEmpty {
            list = [.init(
                title: "Todo en orden",
                message: "Condiciones estables por ahora. ¡Buen trabajo! 🌱",
                level: .ok
            )]
        }
        
        alerts = list
    }
}
#Preview {
    HomeView()
}
