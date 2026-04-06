//
//  AnticipaView.swift
//  KafeCam
//
//  Created by Guillermo Lira on 30/09/25.
//

import SwiftUI

// vista simple

struct AnticipaView: View {
    @StateObject private var vm = AnticipaViewModel()

    // colores verdes
    let accent1  = Color(red: 88/255, green: 129/255, blue: 87/255)
    let accent2   = Color(red: 82/255,  green: 76/255,  blue: 41/255)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                header

                // alertas
                if !vm.risks.isEmpty {
                    Text("Alertas")
                        .font(.headline)
                        .foregroundColor(accent1)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(vm.risks) { r in
                                AnticipaAlertBadge(
                                    title: shortTitle(for: r),
                                    message: alertMessage(for: r),
                                    level: alertLevel(for: r)
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                if vm.isLoading {
                    ProgressView("Cargando…")
                }

                if let err = vm.error {
                    Text(err).foregroundStyle(.red)
                    Button("Reintentar") { vm.reload() }
                        .buttonStyle(.borderedProminent)
                        .tint(accent1)
                }

                if let b = vm.bundle {
                    todayCard(b.current)

                    if !vm.summary.isEmpty {
                        Text(vm.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !vm.actions.isEmpty {
                        actionsCard(vm.actions)
                    }

                    if !b.nextDays.isEmpty {
                        nextDaysStrip(b.nextDays)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Anticipa")
        .onAppear { vm.onAppear() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Anticipa").font(.title2).bold()
                Text(vm.bundle?.locationName ?? "Cargando ubicación…")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Button { vm.reload() } label: {
                Image(systemName: "arrow.clockwise").imageScale(.large)
            }
            .buttonStyle(.borderless)
            .tint(accent2)
        }
    }
    
    private func todayCard(_ c: CurrentWeather) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(Int(round(c.tempC)))°C", systemImage: "thermometer")
                    .font(.title2).bold()
                Spacer()
            }
            HStack {
                Label("\(c.humidityPct)%", systemImage: "humidity")
                Spacer()
                Label("\(Int(round(c.windKph))) kph", systemImage: "wind")
                Spacer()
                Label("\(Int(round(c.rainMm))) mm", systemImage: "cloud.rain")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func actionsCard(_ items: [AnticipaAction]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Acciones sugeridas").font(.headline)
            ForEach(items) { a in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(accent1)
                    Text(a.text).font(.footnote)
                    Spacer()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func nextDaysStrip(_ days: [DailyForecast]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Próximos 3 días").font(.headline)
            HStack {
                ForEach(days.indices, id: \.self) { i in
                    let d = days[i]
                    dayCell(d)
                }
            }
        }
    }

    private func dayCell(_ d: DailyForecast) -> some View {
        VStack(spacing: 6) {
            Text(shortWeekday(d.date)).font(.footnote)
            Text("\(Int(d.tMaxC))° / \(Int(d.tMinC))°").font(.caption)
            HStack(spacing: 6) {
                Image(systemName: "cloud.rain")
                Text("\(Int(d.rainSumMm))")
                Image(systemName: "wind")
                Text("\(Int(d.windMaxKph))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "E"
        return f.string(from: date)
    }

    // mapeos

    private func shortTitle(for r: AnticipaRisk) -> String {
        switch r {
        case .humedadLluvia: return "Humedad/Lluvia"
        case .vientoFuerte:  return "Viento fuerte"
        case .estresTermico: return "Estrés térmico"
        case .ventanaSeca:   return "Ventana seca"
        case .riesgoRoya:    return "Riesgo de roya"
        }
    }

    private func alertMessage(for r: AnticipaRisk) -> String {
        switch r {
        case .humedadLluvia: return "Evita aplicaciones y revisa hojas."
        case .vientoFuerte:  return "Precaución en zonas arboladas."
        case .estresTermico: return "Planear actividades en horas frescas."
        case .ventanaSeca:   return "Buen momento para corte y tendido."
        case .riesgoRoya:    return "Monitoreo del envés de hojas."
        }
    }

    private func alertLevel(for r: AnticipaRisk) -> AnticipaAlertLevel {
        switch r {
        case .ventanaSeca:   return .ok
        case .vientoFuerte:  return .warn
        case .estresTermico: return .warn
        case .humedadLluvia: return .warn
        case .riesgoRoya:    return .warn
        }
    }
}

// badge simple

enum AnticipaAlertLevel { case ok, warn, danger }

struct AnticipaAlertBadge: View {
    let title: String
    let message: String
    let level: AnticipaAlertLevel
    
    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 92

    private var bg: Color {
        switch level {
        case .ok:    return Color.green.opacity(0.15)
        case .warn:  return Color.yellow.opacity(0.15)
        case .danger:return Color.red.opacity(0.15)
        }
    }
    private var border: Color {
        switch level {
        case .ok:    return .green
        case .warn:  return .yellow
        case .danger:return .red
        }
    }
    private var icon: String {
        switch level {
        case .ok:    return "checkmark.seal.fill"
        case .warn:  return "exclamationmark.triangle.fill"
        case .danger:return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(bg))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(border.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(width: 260, alignment: .leading)
    }
}
#Preview {
    AnticipaView()
}
