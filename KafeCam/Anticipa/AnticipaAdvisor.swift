//
//  AnticipaAdvisor.swift
//  KafeCam
//

import Foundation

struct AnticipaAdvisor {
    struct Output: Equatable {
        let risks: [AnticipaRisk]
        let actions: [AnticipaAction]
        let summary: String
    }

    func evaluate(bundle: WeatherBundle) -> Output {
        let c    = bundle.current
        let days = bundle.nextDays

        var risks   = Set<AnticipaRisk>()
        var actions: [String] = []

        // humedad alta / lluvia próxima
        let highHum  = c.humidityPct >= 80
        let rainSoon = days.dropFirst().prefix(2).contains { $0.rainSumMm >= 5.0 }
        if highHum || rainSoon {
            risks.insert(.humedadLluvia)
            risks.insert(.riesgoRoya)
            actions.append(L("Revisar envés de hojas por roya/mildiu."))
            actions.append(L("Recolectar frutos caídos antes de lluvia."))
        }

        // viento fuerte
        if days.contains(where: { $0.windMaxKph >= 35 }) {
            risks.insert(.vientoFuerte)
            actions.append(L("Retirar ramas sueltas cercanas a cafetos."))
            actions.append(L("Evitar transitar en zonas arboladas con viento."))
        }

        // estrés térmico
        if c.tempC >= 34 && c.humidityPct < 50 {
            risks.insert(.estresTermico)
            actions.append(L("Mover grano cosechado a sombra natural."))
            actions.append(L("Planear actividades en horas frescas."))
        }

        // ventana seca (oportunidad)
        let next3          = Array(days.dropFirst().prefix(3))
        let noRain         = next3.allSatisfy { $0.rainSumMm <= 3.0 }
        let lowWindEnough  = next3.filter { $0.windMaxKph < 30 }.count >= 2
        if noRain && lowWindEnough {
            risks.insert(.ventanaSeca)
            actions.append(L("Programar corte y tendido para secado."))
            actions.append(L("Mantener claras veredas naturales."))
        }

        let summary: String
        if risks.isEmpty {
            summary = L("Condiciones estables.")
        } else {
            summary = String(format: L("%d evento(s) detectado(s)."), risks.count)
        }

        let uniqActions = Array(Set(actions)).map { AnticipaAction(text: $0) }
        return Output(risks: Array(risks), actions: uniqActions, summary: summary)
    }
}

// Shorthand so the call sites stay readable.
private func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
