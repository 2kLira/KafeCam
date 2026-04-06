//
//  AnticipaModel.swift
//  KafeCam
//
//  Created by Guillermo Lira on 30/09/25.
//

import Foundation

// modelos

struct CurrentWeather: Equatable {
    let date: Date
    let tempC: Double
    let humidityPct: Int
    let windKph: Double
    let rainMm: Double
}

struct DailyForecast: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let tMinC: Double
    let tMaxC: Double
    let humidityMeanPct: Int
    let windMaxKph: Double
    let rainSumMm: Double
}

struct WeatherBundle: Equatable {
    let locationName: String
    let current: CurrentWeather
    let nextDays: [DailyForecast]
}

enum AnticipaRisk: String, CaseIterable, Identifiable {
    case humedadLluvia = "Alta humedad / lluvia próxima"
    case vientoFuerte  = "Viento fuerte"
    case estresTermico = "Estrés térmico"
    case ventanaSeca   = "Ventana seca"
    case riesgoRoya    = "Riesgo de roya"
    var id: String { rawValue }
}

struct AnticipaAction: Identifiable, Equatable {
    let id = UUID()
    let text: String
}
