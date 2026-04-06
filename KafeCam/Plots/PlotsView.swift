//
// PlotsView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import SwiftUI

struct PlotsView: View {
	@StateObject private var vm = PlotsViewModel()
	@State private var showingAdd = false
	
	var body: some View {
		NavigationStack {
			List(vm.plots) { p in
				VStack(alignment: .leading, spacing: 4) {
					Text(p.name).font(.headline)
					if let region = p.region { Text(region).font(.subheadline).foregroundStyle(.secondary) }
					if let lat = p.lat, let lon = p.lon { Text("(\(lat), \(lon))").font(.caption).foregroundStyle(.secondary) }
				}
			}
			.overlay {
				if vm.isLoading { ProgressView() }
			}
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						showingAdd = true
					} label: {
						Image(systemName: "plus")
					}
				}
			}
			.navigationTitle("My Plots")
		}
		.task { vm.onAppear() }
		.alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
			Button("OK") { vm.errorMessage = nil }
		} message: {
			Text(vm.errorMessage ?? "")
		}
		.sheet(isPresented: $showingAdd) {
			AddPlotSheet { name, lat, lon, region in
				Task { await vm.createPlot(name: name, lat: lat, lon: lon, region: region) }
			}
		}
	}
}

private struct AddPlotSheet: View {
	var onSave: (String, Double?, Double?, String?) -> Void
	@Environment(\.dismiss) private var dismiss
	@State private var name: String = ""
	@State private var region: String = ""
	@State private var lat: String = ""
	@State private var lon: String = ""
	
	var body: some View {
		NavigationStack {
			Form {
				Section("Details") {
					TextField("Name", text: $name)
					TextField("Region (optional)", text: $region)
					TextField("Latitude (optional)", text: $lat).keyboardType(.decimalPad)
					TextField("Longitude (optional)", text: $lon).keyboardType(.decimalPad)
				}
			}
			.navigationTitle("New Plot")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						let latVal = Double(lat)
						let lonVal = Double(lon)
						onSave(name, latVal, lonVal, region.isEmpty ? nil : region)
						dismiss()
					}
					.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}
			}
		}
	}
}

#Preview { PlotsView() }
