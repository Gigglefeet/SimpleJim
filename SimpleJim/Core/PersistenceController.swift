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
        
        // Enable lightweight migration for safe schema evolution
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        var didAttemptRepair = false

        let persistentContainer = container
        let coordinator = persistentContainer.persistentStoreCoordinator

        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error = error {
                Self.logger.error("Core Data failed to load store: \(error.localizedDescription)")
                if !didAttemptRepair, let storeURL = storeDescription.url {
                    didAttemptRepair = true
                    do {
                        try coordinator.destroyPersistentStore(
                            at: storeURL,
                            ofType: NSSQLiteStoreType,
                            options: nil
                        )
                        Self.logger.info("Destroyed corrupted Core Data store. Attempting to recreate…")
                        persistentContainer.loadPersistentStores { _, secondError in
                            if let secondError = secondError {
                                Self.logger.error("Core Data recovery failed: \(secondError.localizedDescription)")
                            } else {
                                Self.logger.info("Core Data store recreated successfully after repair.")
                                UserDefaults.standard.set(true, forKey: "coreDataStoreRepaired")
                            }
                        }
                    } catch {
                        Self.logger.error("Failed to destroy corrupted store: \(error.localizedDescription)")
                    }
                }
            } else {
                Self.logger.info("Core Data store loaded successfully")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
} 

// MARK: - Units Helper (in-target)

struct Units {
    static func kgToDisplay(_ kilograms: Double, unit: String) -> Double {
        if unit.lowercased() == "lbs" || unit.lowercased() == "pounds" { return kilograms * 2.2046226218 }
        return kilograms
    }
    static func displayToKg(_ value: Double, unit: String) -> Double {
        if unit.lowercased() == "lbs" || unit.lowercased() == "pounds" { return value / 2.2046226218 }
        return value
    }
    static func unitSuffix(_ unit: String) -> String {
        if unit.lowercased() == "lbs" || unit.lowercased() == "pounds" { return "lb" }
        return "kg"
    }
} 