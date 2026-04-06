//
//  PlayerListScreen.swift
//  Player
//
//  Created by Grecia Saucedo on 09/10/25.
//

import SwiftUI
import SwiftData

struct PlayerListScreen: View {
    @Query private var players: [Player]
    @State private var isAddPlayerPresented: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(self.players) {player in Text(player.name
                    Text(player.username)
                                                      
                )
                }
            }
            ScrollView {
                VStack {
                    
                }
                .navigationTitle("Players")
                .navigationSubtitle("Lista de jugadores")
                .naviagationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem {
                        Button ("Agregar", systemImage: "plus") {
                            self.$isAddPlayerPresented = true
                        }
                    }
                }
            }
            .sheet(isPresented: self.$isAddPlayerPresented) {
                AddPlayerScreen()
                    .presentationDetents([.medium])
            }
        }
    }
}

#Preview {
    PlayerListScreen()
}
