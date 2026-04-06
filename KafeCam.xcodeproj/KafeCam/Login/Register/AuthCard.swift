//
//  AuthCard.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//

import SwiftUI

struct AuthCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 226/255, green: 219/255, blue: 199/255)) // #E2DBC7
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
}

