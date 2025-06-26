import Foundation
import CoreData

// Core Data generates the main class, we just add extensions
extension CompletedExercise {
    
    // Computed properties
    var sets: [ExerciseSet] {
        guard let exerciseSets = exerciseSets?.allObjects as? [ExerciseSet] else { return [] }
        return exerciseSets.sorted { $0.order < $1.order }
    }
    
    var totalWeight: Double {
        return sets.reduce(0) { total, set in
            total + (set.weight * Double(set.reps))
        }
    }
    
    var maxWeight: Double {
        return sets.map { $0.weight }.max() ?? 0
    }
    
    var totalReps: Int {
        return sets.reduce(0) { total, set in
            total + Int(set.reps)
        }
    }
    
    var name: String {
        return template?.name ?? "Unknown Exercise"
    }
    
    var muscleGroup: String {
        return template?.muscleGroup ?? "Unknown"
    }
}

 