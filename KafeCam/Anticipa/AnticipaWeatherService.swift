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
        guard let url = comps.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300 ~= http.statusCode) {
            throw URLError(.badServerResponse)
        }
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
        let d = om.daily
        // Open-Meteo can return parallel arrays of different lengths (or omit some);
        // bound the loop by the SHORTEST array to avoid an index-out-of-range crash.
        let count = min(d.time.count, d.temperature_2m_min.count, d.temperature_2m_max.count,
                        d.relative_humidity_2m_mean.count, d.wind_speed_10m_max.count,
                        d.precipitation_sum.count, 4) // hoy + 3
        if count > 0 {
            for i in 0..<count {
                days.append(DailyForecast(
                    date: Self.parseDay(d.time[i]),
                    tMinC: d.temperature_2m_min[i],
                    tMaxC: d.temperature_2m_max[i],
                    humidityMeanPct: d.relative_humidity_2m_mean[i],
                    windMaxKph: d.wind_speed_10m_max[i],
                    rainSumMm: d.precipitation_sum[i]
                ))
            }
        }
        return WeatherFetchResult(current: cur, nextDays: days)
    }

    private static func parseISO(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTime]
        if let d = f.date(from: s) { return d }
        // Open-Meteo "current.time" has no seconds/zone (e.g. "2026-06-06T14:30").
        let f2 = DateFormatter()
        f2.locale = Locale(identifier: "en_US_POSIX")
        f2.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f2.date(from: s) ?? Date()
    }

    /// Daily `time` entries are date-only ("2026-06-06"); the ISO formatter rejects
    /// them and would fall back to today for every cell. Parse them explicitly.
    private static func parseDay(_ s: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s) ?? Date()
    }
}
