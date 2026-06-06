//
//  AnticipaLocation.swift
//  KafeCam
//
//  Created by Guillermo Lira on 30/09/25.
//


import Foundation
import CoreLocation

// ubicación simple

final class AnticipaLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var coord: CLLocationCoordinate2D?

    /// Called on the main thread when the first/updated fix arrives, so the VM can
    /// re-fetch weather for the real location instead of staying on the fallback.
    var onUpdate: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestOnce() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.first?.coordinate else { return }
        DispatchQueue.main.async {
            self.coord = c
            self.onUpdate?(c)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // no-op
    }
}
