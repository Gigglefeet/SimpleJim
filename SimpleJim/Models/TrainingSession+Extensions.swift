import Foundation
import CoreData

extension TrainingSession {
    
    var sortedCompletedExercises: [CompletedExercise] {
        guard let exercises = completedExercises?.allObjects as? [CompletedExercise] else { return [] }
        return exercises.sorted { $0.template?.order ?? 0 < $1.template?.order ?? 0 }
    }
    
    var totalWeightLifted: Double {
        return sortedCompletedExercises.reduce(0) { total, exercise in
            total + exercise.totalWeight
        }
    }
    
    var totalSets: Int {
        return sortedCompletedExercises.reduce(0) { total, exercise in
            total + exercise.sets.count
        }
    }
    
    var duration: TimeInterval {
        // Calculate based on sets and rest time - placeholder for now
        return TimeInterval(totalSets * 180) // 3 minutes per set average
    }
    
    var recoveryDays: Int {
        guard let template = template,
              let program = template.program else { return 0 }
        
        let calendar = Calendar.current
        let fetchRequest: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "template.program == %@ AND date < %@", program, (date ?? Date()) as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        guard let context = managedObjectContext,
              let lastSession = try? context.fetch(fetchRequest).first else {
            return 0
        }
        
        return calendar.dateComponents([.day], from: lastSession.date ?? Date(), to: date ?? Date()).day ?? 0
    }
} 