import Foundation
import CoreData

// Core Data generates the main class, we just add extensions
extension TrainingDayTemplate {
    
    // Computed properties
    var sortedExerciseTemplates: [ExerciseTemplate] {
        guard let exerciseTemplates = exerciseTemplates?.allObjects as? [ExerciseTemplate] else { return [] }
        return exerciseTemplates.sorted { $0.order < $1.order }
    }
    
    var totalExercises: Int {
        return exerciseTemplates?.count ?? 0
    }
    
    var sessionHistory: [TrainingSession] {
        guard let sessions = trainingSessions?.allObjects as? [TrainingSession] else { return [] }
        return sessions.sorted { $0.date > $1.date }
    }
    
    var lastSession: TrainingSession? {
        return sessionHistory.first
    }
}

 