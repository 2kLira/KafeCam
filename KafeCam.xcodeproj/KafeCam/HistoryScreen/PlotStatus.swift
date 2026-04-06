import Foundation

enum PlotStatus: String, Codable, CaseIterable, Identifiable {
    case sano
    case sospecha
    case enfermo
    
    // Para conformar a Identifiable
    var id: String { self.rawValue }
}
