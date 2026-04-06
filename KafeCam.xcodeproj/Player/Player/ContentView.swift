//
//  ContentView.swift
//  Player
//
//  Created by Grecia Saucedo on 09/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        VStack {
            TabView {
                Tab("Players", systemImage: "person.fil"){
                    PlayerListScreen()
                }
                Tab("Favorites", systemImage: "star")
            }
            
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
