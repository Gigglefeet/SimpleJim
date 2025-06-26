import Foundation
import CoreData

extension CompletedExercise {
    
    var sets: [ExerciseSet] {
        guard let sets = exerciseSets?.allObjects as? [ExerciseSet] else { return [] }
        return sets.sorted { $0.order < $1.order }
    }
    
    var totalWeight: Double {
        return sets.reduce(0) { total, set in
            total + (set.weight * Double(set.reps))
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