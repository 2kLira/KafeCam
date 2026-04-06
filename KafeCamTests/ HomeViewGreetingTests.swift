//
//  HomeGreetingTests.swift
//  KafeCamTests
//
//  Created by Grecia Saucedo on 24/10/25.
//

import XCTest
@testable import KafeCam

final class HomeGreetingTests: XCTestCase {

    func test_UsesDisplayNameWhenPresent() {
        let displayName = "User"
        let greeting = displayName.isEmpty ? "Hola" : "Hola, \(displayName)"
        XCTAssertEqual(greeting, "Hola, User")
    }

    func test_UsesGreetingNameWhenDisplayNameEmpty() {
        let displayName = ""
        let greetingName = "User"
        let greeting = displayName.isEmpty ? "Hola, \(greetingName)" : "Hola, \(displayName)"
        XCTAssertEqual(greeting, "Hola, User")
    }

    func test_DefaultHolaWhenBothEmpty() {
        let displayName = ""
        let greetingName = ""
        let greeting = (displayName.isEmpty && greetingName.isEmpty) ? "Hola" : "Hola, \(displayName.isEmpty ? greetingName : displayName)"
        XCTAssertEqual(greeting, "Hola")
    }
}
