//
//  AddPlayerScreen.swift
//  Player
//
//  Created by Grecia Saucedo on 09/10/25.
//

import SwiftUI

struct AddPlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var score: Int = 0
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre", text: self.$name)
                TextField("User", text: self.$username)
                TextField("Score", value: self.$score, format: .number)
                
                Button("Save") {
                    let player: Player = Player
                    (name: self.name, username: self.username, score: self.score)
                    
                    self.context.insert(player)
                    
                    do {
                        try self.context.save()
                    } catch {
                        print(error)
                    }
                    self.dismiss()
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitle
            .toolbar {
                ToolbarItem {
                    
                    Button("Close", systemImage: "xmark") {
                        self.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddPlayerScreen()
            .modelContainer(for: [Player.self])
    }
}
