//
// PlotsRepositoryQueryTests.swift
// KafeCamTests
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import XCTest
@testable import KafeCam

private enum QueryHelper {
	static func ownerIdFilter(_ id: UUID) -> (column: String, value: String) {
		("owner_user_id", id.uuidString)
	}
}

final class PlotsRepositoryQueryTests: XCTestCase {
	func testOwnerIdFilter() {
		let userId = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
		let filter = QueryHelper.ownerIdFilter(userId)
		XCTAssertEqual(filter.column, "owner_user_id")
		XCTAssertEqual(filter.value, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
	}
}
