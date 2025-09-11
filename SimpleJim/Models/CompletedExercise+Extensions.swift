import Foundation
import CoreData

extension CompletedExercise {
    
    var sets: [ExerciseSet] {
        guard let sets = exerciseSets?.allObjects as? [ExerciseSet] else { return [] }
        return sets.sorted { $0.order < $1.order }
    }
    
    var totalWeight: Double {
        return sets.reduce(0) { total, set in
            total + (set.effectiveWeight * Double(set.reps))
        }
    }
    
    var isCompleted: Bool {
        return !sets.isEmpty && sets.allSatisfy { $0.isCompleted }
    }
    
    var completedSets: Int {
        return sets.filter { $0.isCompleted }.count
    }
    
    var totalSets: Int {
        return sets.count
    }
}

// MARK: - ExerciseSet Extension for Bodyweight

extension ExerciseSet {
    /// The effective weight used for calculations (bodyweight + extra weight if bodyweight exercise, otherwise just weight)
    var effectiveWeight: Double {
        if isBodyweight {
            let defaultBW = UserDefaults.standard.double(forKey: "defaultBodyweight")
            let fallbackBW = defaultBW != 0 ? defaultBW : 70.0
            let bodyweight = session?.userBodyweight ?? fallbackBW
            return bodyweight + extraWeight
        } else {
            return weight
        }
    }
    
    /// Computed property to get the training session this set belongs to
    var session: TrainingSession? {
        return completedExercise?.session
    }
    
    /// Whether this set has valid input (either weight > 0 OR bodyweight is enabled)
    var hasValidWeight: Bool {
        if isBodyweight {
            return true // Bodyweight is always valid
        } else {
            return weight > 0
        }
    }
} 