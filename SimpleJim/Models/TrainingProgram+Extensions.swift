import Foundation
import CoreData

extension TrainingProgram {
    
    var sortedDayTemplates: [TrainingDayTemplate] {
        guard let templates = dayTemplates?.allObjects as? [TrainingDayTemplate] else { return [] }
        return templates.sorted { $0.order < $1.order }
    }
    
    var totalDays: Int {
        return dayTemplates?.count ?? 0
    }
} 