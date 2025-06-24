import Foundation
import CoreData

@objc(Exercise)
public class Exercise: NSManagedObject {
    
}

extension Exercise {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Exercise> {
        return NSFetchRequest<Exercise>(entityName: "Exercise")
    }
    
    @NSManaged public var name: String
    @NSManaged public var muscleGroup: String
    @NSManaged public var notes: String?
    @NSManaged public var order: Int16
    @NSManaged public var trainingDay: TrainingDay?
    @NSManaged public var exerciseSets: NSSet?
    
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
}

// MARK: Generated accessors for exerciseSets
extension Exercise {
    
    @objc(addExerciseSetsObject:)
    @NSManaged public func addToExerciseSets(_ value: ExerciseSet)
    
    @objc(removeExerciseSetsObject:)
    @NSManaged public func removeFromExerciseSets(_ value: ExerciseSet)
    
    @objc(addExerciseSets:)
    @NSManaged public func addToExerciseSets(_ values: NSSet)
    
    @objc(removeExerciseSets:)
    @NSManaged public func removeFromExerciseSets(_ values: NSSet)
}

extension Exercise: Identifiable {
    
} 