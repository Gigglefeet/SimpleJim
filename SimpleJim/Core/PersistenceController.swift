import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews ONLY
        #if DEBUG
        let sampleTrainingDay = TrainingDay(context: viewContext)
        sampleTrainingDay.date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        sampleTrainingDay.sleepHours = 7.5
        sampleTrainingDay.proteinGrams = 150
        
        let sampleExercise = Exercise(context: viewContext)
        sampleExercise.name = "Sample Bench Press"
        sampleExercise.muscleGroup = "Chest"
        sampleExercise.order = 0
        sampleExercise.trainingDay = sampleTrainingDay
        
        let sampleSet1 = ExerciseSet(context: viewContext)
        sampleSet1.weight = 80
        sampleSet1.reps = 8
        sampleSet1.order = 0
        sampleSet1.isCompleted = true
        sampleSet1.exercise = sampleExercise
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
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
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
} 