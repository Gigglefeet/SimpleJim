import CoreData
import os.log

struct PersistenceController {
    static let shared = PersistenceController()
    
    private static let logger = Logger(subsystem: "com.simplejim.app", category: "CoreData")

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews ONLY
        #if DEBUG
        let sampleProgram = TrainingProgram(context: viewContext)
        sampleProgram.name = "Sample Push/Pull/Legs"
        sampleProgram.notes = "6-day training program"
        sampleProgram.createdDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let pushDay = TrainingDayTemplate(context: viewContext)
        pushDay.name = "Push Day"
        pushDay.order = 0
        pushDay.program = sampleProgram
        
        let benchPress = ExerciseTemplate(context: viewContext)
        benchPress.name = "Bench Press"
        benchPress.muscleGroup = "Chest"
        benchPress.targetSets = 4
        benchPress.order = 0
        benchPress.dayTemplate = pushDay
        
        let sampleSession = TrainingSession(context: viewContext)
        sampleSession.date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        sampleSession.sleepHours = 7.5
        sampleSession.proteinGrams = 150
        sampleSession.template = pushDay
        
        let completedBench = CompletedExercise(context: viewContext)
        completedBench.template = benchPress
        completedBench.session = sampleSession
        
        let set1 = ExerciseSet(context: viewContext)
        set1.weight = 80
        set1.reps = 8
        set1.order = 0
        set1.isCompleted = true
        set1.completedExercise = completedBench
        
        do {
            try viewContext.save()
        } catch {
            Self.logger.error("Failed to save preview data: \(error.localizedDescription)")
        }
        #endif
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SimpleJim")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                Self.logger.error("Core Data failed to load store: \(error.localizedDescription)")
                // In production, we should handle this more gracefully
                // For now, we'll continue with the app potentially in a broken state
                // TODO: Add proper error recovery or migration handling
            } else {
                Self.logger.info("Core Data store loaded successfully")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
} 