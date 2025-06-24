import Foundation
import CoreData

@objc(ExerciseSet)
public class ExerciseSet: NSManagedObject {
    
}

extension ExerciseSet {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExerciseSet> {
        return NSFetchRequest<ExerciseSet>(entityName: "ExerciseSet")
    }
    
    @NSManaged public var weight: Double
    @NSManaged public var reps: Int16
    @NSManaged public var order: Int16
    @NSManaged public var isCompleted: Bool
    @NSManaged public var restSeconds: Int16
    @NSManaged public var exercise: Exercise?
    
    // Computed properties
    var volume: Double {
        return weight * Double(reps)
    }
}

extension ExerciseSet: Identifiable {
    
} 