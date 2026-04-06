//
//  MapModelBasicsTests.swift
//  KafeCamTests
//
//  Covers tiny invariants on MapPlotPin and PlotsMapViewModel region helpers.
//

import XCTest
import MapKit
@testable import KafeCam

final class MapModelBasicsTests: XCTestCase {
    func testMapPlotPinEqualityById() {
        let id = UUID()
        let a = MapPlotPin(id: id,
                           coordinate: CLLocationCoordinate2D(latitude: 10, longitude: -84),
                           name: "A",
                           status: .sano,
                           plantedAt: nil)
        var b = a
        b.name = "B" // same id, different name → still equal
        XCTAssertEqual(a, b)
    }

    func testGoToPinSetsRegionCenter() {
        let vm = PlotsMapViewModel()
        let coord = CLLocationCoordinate2D(latitude: 12.34, longitude: -56.78)
        let pin = MapPlotPin(coordinate: coord, name: "Test")
        vm.goToPin(pin)
        XCTAssertEqual(vm.region.center.latitude, coord.latitude, accuracy: 0.0001)
        XCTAssertEqual(vm.region.center.longitude, coord.longitude, accuracy: 0.0001)
    }
}


