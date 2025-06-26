import Foundation
import CoreData

// Core Data generates the main class, we just add extensions
extension TrainingProgram {
    
    // Computed properties
    var sortedDayTemplates: [TrainingDayTemplate] {
        guard let dayTemplates = dayTemplates?.allObjects as? [TrainingDayTemplate] else { return [] }
        return dayTemplates.sorted { $0.order < $1.order }
    }
    
    var totalDays: Int {
        return dayTemplates?.count ?? 0
    }
}

 