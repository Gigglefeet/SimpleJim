import Foundation
import CoreData

@objc(TrainingDay)
public class TrainingDay: NSManagedObject {
    
}

extension TrainingDay {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TrainingDay> {
        return NSFetchRequest<TrainingDay>(entityName: "TrainingDay")
    }
    
    @NSManaged public var date: Date
    @NSManaged public var sleepHours: Double
    @NSManaged public var proteinGrams: Double
    @NSManaged public var notes: String?
    @NSManaged public var exercises: NSSet?
    
    // Computed properties
    var recoveryDays: Int {
        let calendar = Calendar.current
        let fetchRequest: NSFetchRequest<TrainingDay> = TrainingDay.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date < %@", date as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        guard let context = managedObjectContext,
              let lastTrainingDay = try? context.fetch(fetchRequest).first else {
            return 0
        }
        
        return calendar.dateComponents([.day], from: lastTrainingDay.date, to: date).day ?? 0
    }
    
    var totalWeightLifted: Double {
        guard let exercises = exercises?.allObjects as? [Exercise] else { return 0 }
        return exercises.reduce(0) { total, exercise in
            total + exercise.totalWeight
        }
    }
    
    var totalSets: Int {
        guard let exercises = exercises?.allObjects as? [Exercise] else { return 0 }
        return exercises.reduce(0) { total, exercise in
            total + exercise.sets.count
        }
    }
}

// MARK: Generated accessors for exercises
extension TrainingDay {
    
    @objc(addExercisesObject:)
    @NSManaged public func addToExercises(_ value: Exercise)
    
    @objc(removeExercisesObject:)
    @NSManaged public func removeFromExercises(_ value: Exercise)
    
    @objc(addExercises:)
    @NSManaged public func addToExercises(_ values: NSSet)
    
    @objc(removeExercises:)
    @NSManaged public func removeFromExercises(_ values: NSSet)
}

extension TrainingDay: Identifiable {
    
} 