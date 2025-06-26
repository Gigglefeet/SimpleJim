import Foundation
import CoreData

// Core Data generates the main class, we just add extensions
extension ExerciseTemplate {
    
    // Computed properties
    var exerciseHistory: [CompletedExercise] {
        guard let completed = completedExercises?.allObjects as? [CompletedExercise] else { return [] }
        return completed.sorted { $0.session?.date ?? Date.distantPast > $1.session?.date ?? Date.distantPast }
    }
    
    var lastCompletedExercise: CompletedExercise? {
        return exerciseHistory.first
    }
    
    var personalRecord: Double {
        return exerciseHistory.compactMap { $0.maxWeight }.max() ?? 0
    }
}

 