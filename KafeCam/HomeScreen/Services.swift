//
//  Services.swift
//  KafeCam
//
//  Created by Grecia Saucedo on 08/09/25.
//
import Foundation

protocol CameraUsageService {
    func daysSinceLastPhoto() -> Int
}

protocol SoilSensorService {
    func soilMoisturePercent() -> Int
    func soilTempCelsius() -> Int
}

struct MockCameraUsageService: CameraUsageService {
    func daysSinceLastPhoto() -> Int { 7 }
}

struct MockSoilSensorService: SoilSensorService {
    func soilMoisturePercent() -> Int { 18 }
    func soilTempCelsius() -> Int { 24 }
}
