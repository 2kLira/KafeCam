//
//  AnticipaViewModel.swift
//  KafeCam
//
//  Created by Guillermo Lira on 30/09/25.
//


import Foundation
import CoreLocation

// vm simple sin Combine

@MainActor
final class AnticipaViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var bundle: WeatherBundle?
    @Published var risks: [AnticipaRisk] = []
    @Published var actions: [AnticipaAction] = []
    @Published var summary: String = ""

    private let service: AnticipaWeatherService
    private let advisor = AnticipaAdvisor()
    private let location = AnticipaLocation()

    // fallback
    private let fallback = CLLocationCoordinate2D(latitude: 25.6866, longitude: -100.3161)

    init(service: AnticipaWeatherService = OpenMeteoService()) {
        self.service = service
    }

    func onAppear() {
        location.requestOnce()
        Task { await load() }
    }

    func reload() {
        location.requestOnce()
        Task { await load() }
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        error = nil
        do {
            let c = location.coord ?? fallback
            let data = try await service.fetch(lat: c.latitude, lon: c.longitude)
            let named = WeatherBundle(
                locationName: (location.coord == nil ? "Monterrey, NL" : "Ubicación actual"),
                current: data.current,
                nextDays: data.nextDays
            )
            self.bundle = named
            let out = advisor.evaluate(bundle: named)
            self.risks = out.risks
            self.actions = out.actions
            self.summary = out.summary
        } catch {
            self.error = "No se pudo cargar el clima."
        }
        isLoading = false
    }
}
