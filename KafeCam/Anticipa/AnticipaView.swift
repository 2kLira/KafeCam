import SwiftUI

struct AnticipaView: View {
    @EnvironmentObject private var vm: AnticipaViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                locationHeader

                // Alertas de riesgo
                if !vm.risks.isEmpty {
                    Text("Alertas")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)

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

                // Error state
                if let err = vm.error {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                    Button("Reintentar") { vm.reload() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                }

                // Loading skeleton or actual content
                if vm.isLoading && vm.bundle == nil {
                    loadingSkeleton
                        .transition(.opacity)
                } else if let b = vm.bundle {
                    VStack(alignment: .leading, spacing: 16) {
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
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .navigationTitle("Anticipa")
        .animation(.easeOut(duration: AppTheme.animNormal), value: vm.isLoading)
        .animation(.easeOut(duration: AppTheme.animNormal), value: vm.bundle == nil)
        .onAppear { vm.onAppear() }
    }

    // MARK: - Location header (no duplicate title)
    private var locationHeader: some View {
        HStack(alignment: .center) {
            if let locationName = vm.bundle?.locationName {
                Label(locationName, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Label("Cargando ubicación...", systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                vm.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .tint(AppTheme.dark)
            .accessibilityLabel("Actualizar")
        }
    }

    // MARK: - Skeleton loading (shown while fetching data)
    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Today card placeholder
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("--°C").font(.title2.bold())
                    Spacer()
                }
                HStack {
                    Text("---%").font(.subheadline)
                    Spacer()
                    Text("--- kph").font(.subheadline)
                    Spacer()
                    Text("--- mm").font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            // Next days placeholder
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 6) {
                        Text("Lun").font(.footnote)
                        Text("--° / --°").font(.caption)
                        Text("--").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    // MARK: - Today card
    private func todayCard(_ c: CurrentWeather) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(Int(round(c.tempC)))°C", systemImage: "thermometer")
                    .font(.title2.bold())
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
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Actions card
    private func actionsCard(_ items: [AnticipaAction]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Acciones sugeridas").font(.headline)
            ForEach(items) { a in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text(a.text).font(.footnote)
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Next days strip
    private func nextDaysStrip(_ days: [DailyForecast]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Próximos 3 días").font(.headline)
            HStack(spacing: 8) {
                ForEach(days.indices, id: \.self) { i in
                    dayCell(days[i])
                }
            }
        }
    }

    private func dayCell(_ d: DailyForecast) -> some View {
        VStack(spacing: 6) {
            Text(shortWeekday(d.date)).font(.footnote.weight(.medium))
            Text("\(Int(d.tMaxC))° / \(Int(d.tMinC))°")
                .font(.caption)
            HStack(spacing: 4) {
                Image(systemName: "cloud.rain")
                Text("\(Int(d.rainSumMm)) mm")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "E"
        return f.string(from: date)
    }

    // MARK: - Risk label helpers
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

// MARK: - Alert Badge

enum AnticipaAlertLevel { case ok, warn, danger }

struct AnticipaAlertBadge: View {
    let title: String
    let message: String
    let level: AnticipaAlertLevel

    private var bg: Color {
        switch level {
        case .ok:    return Color.green.opacity(0.12)
        case .warn:  return Color.orange.opacity(0.12)
        case .danger: return Color.red.opacity(0.12)
        }
    }
    private var border: Color {
        switch level {
        case .ok:    return Color.green
        case .warn:  return Color.orange   // Changed from .yellow — better accessibility contrast
        case .danger: return Color.red
        }
    }
    private var icon: String {
        switch level {
        case .ok:    return "checkmark.seal.fill"
        case .warn:  return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(border)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(border.opacity(0.5), lineWidth: 1)
                )
        )
        .frame(width: 260, alignment: .leading)
    }
}

#Preview {
    AnticipaView()
        .environmentObject(AnticipaViewModel())
}
