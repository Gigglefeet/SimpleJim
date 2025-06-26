import Foundation
import CoreData

// Core Data generates the main class, we just add extensions
extension ExerciseSet {
    
    // Computed properties
    var volume: Double {
        return weight * Double(reps)
    }
}

 