//
//  AlertCard.swift
//  KafeCam
//
//  Created by Grecia Saucedo on 08/09/25.
//
import SwiftUI

struct AlertCard: View {
    let alert: AlertItem
    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 92
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: alert.level.icon)
                .font(.title3)
                .foregroundColor(alert.level.border)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.subheadline).bold()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 260, alignment: .leading)
        .background(alert.level.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(alert.level.border.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    HomeView()
}

