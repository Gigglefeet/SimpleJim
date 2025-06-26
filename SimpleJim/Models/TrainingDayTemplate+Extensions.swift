import Foundation
import CoreData

extension TrainingDayTemplate {
    
    var sortedExerciseTemplates: [ExerciseTemplate] {
        guard let templates = exerciseTemplates?.allObjects as? [ExerciseTemplate] else { return [] }
        return templates.sorted { $0.order < $1.order }
    }
    
    var totalExercises: Int {
        return exerciseTemplates?.count ?? 0
    }
    
    var lastSession: TrainingSession? {
        guard let sessions = trainingSessions?.allObjects as? [TrainingSession] else { return nil }
        return sessions.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }.first
    }
} 