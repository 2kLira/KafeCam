//
//  AnticipaWeatherService.swift
//  KafeCam
//
//  Created by Guillermo Lira on 30/09/25.
//

import Foundation

// respuesta simple

struct WeatherFetchResult {
    let current: CurrentWeather
    let nextDays: [DailyForecast]
}

// servicio

protocol AnticipaWeatherService {
    func fetch(lat: Double, lon: Double) async throws -> WeatherFetchResult
}

// open-meteo

private struct OMResponse: Codable {
    struct Current: Codable {
        let time: String
        let temperature_2m: Double
        let relative_humidity_2m: Int
        let precipitation: Double
        let wind_speed_10m: Double
    }
    struct Daily: Codable {
        let time: [String]
        let temperature_2m_min: [Double]
        let temperature_2m_max: [Double]
        let relative_humidity_2m_mean: [Int]
        let wind_speed_10m_max: [Double]
        let precipitation_sum: [Double]
    }
    let timezone: String
    let current: Current
    let daily: Daily
}

struct OpenMeteoService: AnticipaWeatherService {
    func fetch(lat: Double, lon: Double) async throws -> WeatherFetchResult {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m"),
            .init(name: "daily", value: "temperature_2m_min,temperature_2m_max,relative_humidity_2m_mean,wind_speed_10m_max,precipitation_sum"),
            .init(name: "forecast_days", value: "5"),
            .init(name: "timezone", value: "auto")
        ]
        let url = comps.url!
        let (data, _) = try await URLSession.shared.data(from: url)
        let dec = JSONDecoder()
        let om = try dec.decode(OMResponse.self, from: data)

        let cur = CurrentWeather(
            date: Self.parseISO(om.current.time),
            tempC: om.current.temperature_2m,
            humidityPct: om.current.relative_humidity_2m,
            windKph: om.current.wind_speed_10m,
            rainMm: om.current.precipitation
        )

        var days: [DailyForecast] = []
        let count = min(om.daily.time.count, 4) // hoy + 3
        for i in 0..<count {
            let d = DailyForecast(
                date: Self.parseISO(om.daily.time[i]),
                tMinC: om.daily.temperature_2m_min[i],
                tMaxC: om.daily.temperature_2m_max[i],
                humidityMeanPct: om.daily.relative_humidity_2m_mean[i],
                windMaxKph: om.daily.wind_speed_10m_max[i],
                rainSumMm: om.daily.precipitation_sum[i]
            )
            days.append(d)
        }
        return WeatherFetchResult(current: cur, nextDays: days)
    }

    private static func parseISO(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTime]
        return f.date(from: s) ?? Date()
    }
}
