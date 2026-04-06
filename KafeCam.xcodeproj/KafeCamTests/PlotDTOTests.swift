//
// PlotDTOTests.swift
// KafeCamTests
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import XCTest
@testable import KafeCam

final class PlotDTOTests: XCTestCase {
	func testDecodePlotDTO() throws {
		let json = """
		{
			"id": "11111111-2222-3333-4444-555555555555",
			"name": "Lote A",
			"lat": 10.1234,
			"lon": -84.1234,
			"altitude_m": 1200,
			"region": "Tarrazú",
			"created_at": "2025-09-10T12:34:56Z",
			"owner_user_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
		}
		""".data(using: .utf8)!
		let plot = try JSONDecoder.supabaseDefault.decode(PlotDTO.self, from: json)
		XCTAssertEqual(plot.name, "Lote A")
		XCTAssertEqual(plot.altitudeM, 1200)
		XCTAssertEqual(plot.ownerUserId.uuidString, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
	}
}
