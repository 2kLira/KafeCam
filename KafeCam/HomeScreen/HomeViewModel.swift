//
//  HomeViewModel.swift
//  KafeCam
//
//  Created by Grecia Saucedo on 08/09/25.
//
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var alerts: [AlertItem] = []
    @Published var greetingName: String = ""

    let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    let darkColor   = Color(red: 82/255,  green: 76/255,  blue: 41/255)

    init(greetingName: String? = nil) {
        if let name = greetingName, !name.isEmpty { self.greetingName = name }
    }

    func updateAlerts(from risks: [AnticipaRisk], isLoading: Bool) {
        if isLoading && risks.isEmpty {
            alerts = []
            return
        }
        guard !risks.isEmpty else {
            alerts = [.init(
                title: "Todo en orden",
                message: "Condiciones estables por ahora. ¡Buen trabajo! 🌱",
                level: .ok
            )]
            return
        }
        alerts = risks.map { alertItem(for: $0) }
    }

    private func alertItem(for risk: AnticipaRisk) -> AlertItem {
        switch risk {
        case .humedadLluvia:
            return .init(title: "Humedad/Lluvia",  message: "Evita aplicaciones y revisa hojas.", level: .warning)
        case .vientoFuerte:
            return .init(title: "Viento fuerte",   message: "Precaución en zonas arboladas.", level: .warning)
        case .estresTermico:
            return .init(title: "Estrés térmico",  message: "Planear actividades en horas frescas.", level: .critical)
        case .ventanaSeca:
            return .init(title: "Ventana seca",    message: "Buen momento para corte y tendido.", level: .ok)
        case .riesgoRoya:
            return .init(title: "Riesgo de roya",  message: "Monitoreo del envés de hojas.", level: .critical)
        }
    }
}
#Preview {
    HomeView()
}
