//
//  PlayerApp.swift
//  Player
//
//  Created by Grecia Saucedo on 09/10/25.
//

import SwiftUI
import SwiftData

@main
struct PlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Player.self])
        }
    }
}
