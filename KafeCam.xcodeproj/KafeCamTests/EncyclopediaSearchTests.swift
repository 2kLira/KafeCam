//
//  EncyclopediaSearchTests.swift
//  KafeCamTests
//
//  Created by User on 24/10/25.
//

import XCTest
@testable import KafeCam

final class EncyclopediaSearchTests: XCTestCase {

    // Simulates HomeView.filteredDiseases logic
    func filterDiseases(query: String, data: [String]) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return data.filter { $0.localizedCaseInsensitiveContains(trimmed) }.prefix(10).map { $0 }
    }

    func test_FilterReturnsCorrectDisease() {
        let data = ["Roya del Café",
                    "Deficiencia de Nitrógeno",
                    "Deficiencia de Magnesio",
                    "Deficiencia de Manganeso",
                    "Deficiencia de Hierro"]
        let result = filterDiseases(query: "roya", data: data)
        XCTAssertEqual(result, ["Roya del Café"])
    }

    func test_FilterIsCaseInsensitive() {
        let data = ["Roya del Café",
                    "Deficiencia de Nitrógeno",
                    "Deficiencia de Magnesio",
                    "Deficiencia de Manganeso",
                    "Deficiencia de Hierro"]
        let result = filterDiseases(query: "CAFÉ", data: data)
        XCTAssertEqual(result, ["Roya del Café"])
    }

    func test_FilterTrimsWhitespace() {
        let data = ["Roya del Café",
                    "Deficiencia de Nitrógeno",
                    "Deficiencia de Magnesio",
                    "Deficiencia de Manganeso",
                    "Deficiencia de Hierro"]
        let result = filterDiseases(query: "   hierro   ", data: data)
        XCTAssertEqual(result, ["Deficiencia de Hierro"])
    }

    func test_FilterReturnsEmptyForEmptyQuery() {
        let data = ["Roya del Café",
                    "Deficiencia de Nitrógeno",
                    "Deficiencia de Magnesio",
                    "Deficiencia de Manganeso",
                    "Deficiencia de Hierro"]
        let result = filterDiseases(query: "", data: data)
        XCTAssertTrue(result.isEmpty)
    }

    func test_FilterReturnsPartialMatches() {
        let data = ["Roya del Café",
                    "Deficiencia de Nitrógeno",
                    "Deficiencia de Magnesio",
                    "Deficiencia de Manganeso",
                    "Deficiencia de Hierro"]
        let result = filterDiseases(query: "deficiencia", data: data)
        XCTAssertEqual(result.count, 4) // should match all 4 deficiencies
    }
}
