import SwiftUI

struct HistoryEntry: Identifiable, Hashable {
    let id = UUID()
    let image: UIImage
    let prediction: String
    let date: Date
    var isFavorite: Bool = false
    var diseaseName: String? = nil
    var status: PlotStatus = .sano
    var notes: String = ""
    var captureData: CaptureDTO? = nil
    /// true mientras el diagnóstico espera sincronización con Supabase
    var isPendingSync: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}
