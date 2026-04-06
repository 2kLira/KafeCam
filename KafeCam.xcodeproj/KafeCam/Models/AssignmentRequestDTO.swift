//
// AssignmentRequestDTO.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 02/10/25
//

import Foundation

struct AssignmentRequestDTO: Codable, Identifiable {
    let id: UUID
    let technicianId: UUID
    let farmerId: UUID
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case technicianId = "technician_id"
        case farmerId = "farmer_id"
        case status
        case createdAt = "created_at"
    }
}


