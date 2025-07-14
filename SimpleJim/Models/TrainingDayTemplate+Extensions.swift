import Foundation
import CoreData

extension TrainingDayTemplate {
    
    var sortedExerciseTemplates: [ExerciseTemplate] {
        guard let exercises = exerciseTemplates?.allObjects as? [ExerciseTemplate] else { return [] }
        return exercises.sorted { $0.order < $1.order }
    }
    
    var totalExercises: Int {
        return exerciseTemplates?.count ?? 0
    }
    
    var lastSession: TrainingSession? {
        guard let sessions = trainingSessions?.allObjects as? [TrainingSession] else { return nil }
        return sessions.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }.first
    }
    
    // MARK: - Superset Support
    
    /// Groups exercises by their superset groups and returns them in display order
    var exerciseGroups: [ExerciseGroup] {
        let exercises = sortedExerciseTemplates
        var groups: [ExerciseGroup] = []
        var currentSupersetGroup: [ExerciseTemplate] = []
        var currentSupersetNumber: Int16? = nil
        
        for exercise in exercises {
            let exerciseSupersetGroup = exercise.supersetGroup == 0 ? nil : exercise.supersetGroup
            
            if exerciseSupersetGroup == nil {
                // Standalone exercise: create individual group
                if !currentSupersetGroup.isEmpty {
                    // Finish previous superset first
                    groups.append(ExerciseGroup(exercises: currentSupersetGroup, type: .superset, supersetNumber: currentSupersetNumber))
                    currentSupersetGroup = []
                    currentSupersetNumber = nil
                }
                // Create standalone group with just this exercise
                groups.append(ExerciseGroup(exercises: [exercise], type: .standalone, supersetNumber: nil))
            } else {
                // Superset exercise
                if currentSupersetNumber != exerciseSupersetGroup {
                    // Finish previous superset if exists
                    if !currentSupersetGroup.isEmpty {
                        groups.append(ExerciseGroup(exercises: currentSupersetGroup, type: .superset, supersetNumber: currentSupersetNumber))
                        currentSupersetGroup = []
                    }
                    currentSupersetNumber = exerciseSupersetGroup
                }
                currentSupersetGroup.append(exercise)
            }
        }
        
        // Add the last superset group if exists
        if !currentSupersetGroup.isEmpty {
            groups.append(ExerciseGroup(exercises: currentSupersetGroup, type: .superset, supersetNumber: currentSupersetNumber))
        }
        
        return groups
    }
    
    /// Gets the next available superset group number
    var nextSupersetGroupNumber: Int16 {
        let exercises = sortedExerciseTemplates
        let supersetGroups = exercises.map { $0.supersetGroup }.filter { $0 > 0 }
        return (supersetGroups.max() ?? 0) + 1
    }
    
    /// Creates a superset from the given exercises and automatically reorders them to be adjacent
    func createSuperset(from exercises: [ExerciseTemplate], in context: NSManagedObjectContext) {
        let supersetNumber = nextSupersetGroupNumber
        
        #if DEBUG
        print("📝 Creating superset \(supersetNumber) and reordering exercises:")
        print("   Selected exercises: \(exercises.map { "\($0.name ?? "Unknown") (order: \($0.order))" })")
        #endif
        
        // Step 1: Sort the selected exercises by their current order
        let sortedSelectedExercises = exercises.sorted { $0.order < $1.order }
        
        // Step 2: Find the starting position (lowest order among selected exercises)
        guard let startPosition = sortedSelectedExercises.first?.order else {
            #if DEBUG
            print("❌ No exercises provided for superset creation")
            #endif
            return
        }
        
        // Step 3: Get all exercises and sort them by order
        let allExercises = sortedExerciseTemplates
        
        #if DEBUG
        print("   Before reordering:")
        for (index, exercise) in allExercises.enumerated() {
            print("     \(index): \(exercise.name ?? "Unknown") (order: \(exercise.order))")
        }
        #endif
        
        // Step 4: Create new order array
        var newOrderedExercises: [ExerciseTemplate] = []
        var exerciseIndex = 0
        
        // Add exercises before the superset position
        while exerciseIndex < allExercises.count && allExercises[exerciseIndex].order < startPosition {
            let exercise = allExercises[exerciseIndex]
            if !exercises.contains(exercise) {
                newOrderedExercises.append(exercise)
            }
            exerciseIndex += 1
        }
        
        // Add superset exercises consecutively
        newOrderedExercises.append(contentsOf: sortedSelectedExercises)
        
        // Add remaining exercises (skipping the ones already in superset)
        while exerciseIndex < allExercises.count {
            let exercise = allExercises[exerciseIndex]
            if !exercises.contains(exercise) {
                newOrderedExercises.append(exercise)
            }
            exerciseIndex += 1
        }
        
        // Step 5: Assign new orders and superset groups
        for (index, exercise) in newOrderedExercises.enumerated() {
            exercise.order = Int16(index)
            
            // Assign superset group to selected exercises
            if exercises.contains(exercise) {
                exercise.supersetGroup = supersetNumber
                #if DEBUG
                print("   ✅ \(exercise.name ?? "Unknown"): order \(index), superset \(supersetNumber)")
                #endif
            } else {
                #if DEBUG
                print("   📍 \(exercise.name ?? "Unknown"): order \(index)")
                #endif
            }
        }
        
        #if DEBUG
        print("   After reordering - Superset exercises are now adjacent!")
        #endif
        
        do {
            try context.save()
            #if DEBUG
            print("✅ Superset created and reordered successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save superset: \(error)")
            #endif
        }
    }
    
    /// Removes exercises from their superset (makes them standalone)
    func removeFromSuperset(exercises: [ExerciseTemplate], in context: NSManagedObjectContext) {
        #if DEBUG
        print("📝 Removing exercises from superset:")
        #endif
        
        for exercise in exercises {
            exercise.supersetGroup = 0
            #if DEBUG
            print("   - \(exercise.name ?? "Unknown"): \(exercise.supersetGroup)")
            #endif
        }
        
        do {
            try context.save()
            #if DEBUG
            print("✅ Superset removal saved successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save superset removal: \(error)")
            #endif
        }
    }
}

// MARK: - Supporting Types

enum ExerciseGroupType {
    case standalone
    case superset
}

struct ExerciseGroup: Identifiable {
    let id = UUID()
    let exercises: [ExerciseTemplate]
    let type: ExerciseGroupType
    let supersetNumber: Int16?
    
    var isSuperset: Bool {
        return type == .superset
    }
    
    var displayTitle: String {
        if isSuperset {
            let letter = String(UnicodeScalar(64 + Int(supersetNumber ?? 1))!) // A, B, C...
            return "Superset \(letter)"
        }
        return ""
    }
    
    var supersetLabels: [String] {
        guard isSuperset else { return exercises.map { _ in "" } }
        let letter = String(UnicodeScalar(64 + Int(supersetNumber ?? 1))!)
        return exercises.enumerated().map { "\(letter)\($0.offset + 1)" }
    }
}

// MARK: - ExerciseTemplate Extensions

extension ExerciseTemplate {
    
    /// Whether this exercise is part of a superset
    var isInSuperset: Bool {
        return supersetGroup > 0
    }
    
    /// Gets the superset label for this exercise (e.g., "A1", "B2")
    var supersetLabel: String? {
        guard supersetGroup > 0 else { return nil }
        
        // Get all exercises in this superset to determine the position
        guard let dayTemplate = self.dayTemplate else { return nil }
        let supersetExercises = dayTemplate.sortedExerciseTemplates.filter { 
            $0.supersetGroup == supersetGroup 
        }
        
        guard let index = supersetExercises.firstIndex(of: self) else { return nil }
        
        let letter = String(UnicodeScalar(64 + Int(supersetGroup))!) // A, B, C...
        return "\(letter)\(index + 1)"
    }
    
    /// Gets all other exercises in the same superset
    var supersetPartners: [ExerciseTemplate] {
        guard supersetGroup > 0 else { return [] }
        guard let dayTemplate = self.dayTemplate else { return [] }
        
        return dayTemplate.sortedExerciseTemplates.filter { 
            $0.supersetGroup == supersetGroup && $0 != self 
        }
    }
} 