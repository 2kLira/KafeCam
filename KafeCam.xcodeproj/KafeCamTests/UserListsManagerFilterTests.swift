//
//  UserListsManagerFilterTests.swift
//  KafeCamTests
//
//  Covers filtering logic for custom community lists.
//

import XCTest
@testable import KafeCam

final class UserListsManagerFilterTests: XCTestCase {
    private func makeProfile(id: String, name: String, role: String,
                             organization: String? = nil,
                             country: String? = nil,
                             state: String? = nil,
                             gender: String? = nil) throws -> ProfileDTO {
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "phone": null,
          "email": null,
          "role": "\(role)",
          "organization": \(organization != nil ? "\"\(organization!)\"" : "null"),
          "locale": null,
          "created_at": "2025-09-10",
          "gender": \(gender != nil ? "\"\(gender!)\"" : "null"),
          "date_of_birth": null,
          "age": null,
          "country": \(country != nil ? "\"\(country!)\"" : "null"),
          "state": \(state != nil ? "\"\(state!)\"" : "null"),
          "about": null,
          "show_gender": null,
          "show_date_of_birth": null,
          "show_age": null,
          "show_country": null,
          "show_state": null,
          "show_about": null
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(ProfileDTO.self, from: json)
    }

    func testFilterProfiles_byUserIdsAndRole() throws {
        let p1 = try makeProfile(id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", name: "Tec 1", role: "technician")
        let p2 = try makeProfile(id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", name: "Far 1", role: "farmer")
        let p3 = try makeProfile(id: "cccccccc-cccc-cccc-cccc-cccccccccccc", name: "Tec 2", role: "technician")

        // List keeps only p1 and p3, and also enforces role == technician
        let list = UserList(
            name: "Mi Lista",
            userIds: [p1.id, p3.id],
            filters: ListFilters(organization: nil, country: nil, state: nil, gender: nil, role: "technician")
        )

        let manager = UserListsManager()
        let filtered = manager.filterProfiles([p1, p2, p3], with: list)

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains(where: { $0.id == p1.id }))
        XCTAssertTrue(filtered.contains(where: { $0.id == p3.id }))
        XCTAssertFalse(filtered.contains(where: { $0.id == p2.id }))
    }

    func testListFilters_isEmptyFlag() {
        XCTAssertTrue(ListFilters().isEmpty)
        XCTAssertFalse(ListFilters(role: "farmer").isEmpty)
    }
}


