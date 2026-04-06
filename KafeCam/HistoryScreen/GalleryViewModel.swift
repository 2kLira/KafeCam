//
// GalleryViewModel.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
import SwiftUI

struct CaptureRow: Identifiable, Hashable {
	let id: UUID
	let title: String
	let subtitle: String
	let dateText: String
}

@MainActor
final class GalleryViewModel: ObservableObject {
	@Published var rows: [CaptureRow] = []
	@Published var isLoading = false
	@Published var errorMessage: String? = nil
	
	private let repo = CapturesRepository()
	
	func load() async {
		isLoading = true
		errorMessage = nil
		defer { isLoading = false }
		do {
			// For now fetch all captures for current user by relying on RLS and filtering on client when available
			// If you want a server filter, add .eq("uploaded_by_user_id", userId)
			let captures: [CaptureDTO] = try await fetchCurrentUserCaptures()
			rows = captures.sorted(by: { ($0.takenAt) < ($1.takenAt) }).reversed().map { c in
				CaptureRow(
					id: c.id,
					title: "Foto",
					subtitle: c.deviceModel ?? "iPhone",
					dateText: Self.formatDate(c.takenAt)
				)
			}
		} catch {
			errorMessage = (error as NSError).localizedDescription
		}
	}
	
	private func fetchCurrentUserCaptures() async throws -> [CaptureDTO] {
		// Minimal: list all captures visible to current user; real impl would filter via repo/from
		// Since our repository focuses on inserts, we’ll pull via Supabase client directly when available.
		#if canImport(Supabase)
		let list: [CaptureDTO] = try await SupaClient.shared
			.from("captures")
			.select()
			.order("taken_at", ascending: false)
			.execute()
			.value
		return list
		#else
		return []
		#endif
	}
	
	private static func formatDate(_ date: Date) -> String {
		let f = DateFormatter()
		f.dateStyle = .medium
		f.timeStyle = .none
		return f.string(from: date)
	}
}
