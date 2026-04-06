//
// PlotsViewModel.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
import SwiftUI

@MainActor
final class PlotsViewModel: ObservableObject {
	@Published var plots: [PlotDTO] = []
	@Published var isLoading = false
	@Published var errorMessage: String? = nil
	
	private let repo = PlotsRepository()
	
	func onAppear() {
		Task { await self.bootstrapAndLoad() }
	}
	
	private func bootstrapAndLoad() async {
		isLoading = true
		defer { isLoading = false }
		do {
			try await SupaAuthService.signInDev()
			try await loadPlots()
		} catch {
			self.errorMessage = shortMessage(from: error)
		}
	}
	
	func loadPlots() async throws {
		let list = try await repo.listPlots()
		self.plots = list
	}
	
	func createPlot(name: String, lat: Double?, lon: Double?, region: String?) async {
		isLoading = true
		defer { isLoading = false }
		do {
			let _ = try await repo.createPlot(name: name, lat: lat, lon: lon, region: region)
			try await loadPlots()
		} catch {
			self.errorMessage = shortMessage(from: error)
		}
	}
	
	private func shortMessage(from error: Error) -> String {
		let ns = error as NSError
		return ns.localizedDescription.isEmpty ? "Something went wrong" : ns.localizedDescription
	}
}
