import SwiftUI
import CoreData

struct WorkoutSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let dayTemplate: TrainingDayTemplate
    @ObservedObject var trainingSession: TrainingSession
    
    @State private var currentGroupIndex = 0
    @State private var currentExerciseInGroup = 0
    @State private var showingFinishAlert = false
    @State private var isFinishing = false
    @State private var refreshTrigger = 0
    @State private var showingSleepInput = false
    @State private var showingBodyweightInput = false
    @State private var workoutElapsedTime: TimeInterval = 0
    
    // Rest Timer State
    @State private var restTimeRemaining: TimeInterval = 0
    @State private var restTimerActive = false
    @State private var defaultRestTime: TimeInterval = 90 // 90 seconds default
    @State private var showingRestSettings = false
    
    private let workoutTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let restTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // MARK: - Workout Navigation Logic
    
    private var exerciseGroups: [ExerciseGroup] {
        let groups = dayTemplate.exerciseGroups
        #if DEBUG
        print("🏋️ Exercise groups: \(groups.count)")
        for (index, group) in groups.enumerated() {
            print("   Group \(index): \(group.isSuperset ? "Superset" : "Standalone"), \(group.exercises.count) exercises")
            for exercise in group.exercises {
                print("      - \(exercise.name ?? "Unknown") (superset group: \(exercise.supersetGroup))")
            }
        }
        #endif
        return groups
    }
    
    private var currentGroup: ExerciseGroup? {
        guard currentGroupIndex < exerciseGroups.count else { return nil }
        return exerciseGroups[currentGroupIndex]
    }
    
    var currentExercise: ExerciseTemplate? {
        guard let group = currentGroup else { return nil }
        guard currentExerciseInGroup < group.exercises.count else { return nil }
        return group.exercises[currentExerciseInGroup]
    }
    
    var completedExercise: CompletedExercise? {
        guard let currentEx = currentExercise else { return nil }
        return trainingSession.sortedCompletedExercises.first { $0.template == currentEx }
    }
    
    // Smart navigation properties
    private var isInSuperset: Bool {
        return currentGroup?.isSuperset ?? false
    }
    
    private var nextExerciseInSuperset: ExerciseTemplate? {
        guard let group = currentGroup, group.isSuperset else { return nil }
        let nextIndex = currentExerciseInGroup + 1
        guard nextIndex < group.exercises.count else { return nil }
        return group.exercises[nextIndex]
    }
    
    private var canGoToPreviousExercise: Bool {
        let canGo = currentGroupIndex > 0 || currentExerciseInGroup > 0
        #if DEBUG
        print("🔙 Can go to previous: \(canGo) (groupIndex: \(currentGroupIndex), exerciseInGroup: \(currentExerciseInGroup))")
        #endif
        return canGo
    }
    
    private var canGoToNextExercise: Bool {
        let totalGroups = exerciseGroups.count
        
        if let group = currentGroup, group.isSuperset {
            // In superset: can advance if there are more exercises in the group OR more groups
            let canGo = currentExerciseInGroup < group.exercises.count - 1 || currentGroupIndex < totalGroups - 1
            #if DEBUG
            print("🔜 Can go to next (superset): \(canGo) (exerciseInGroup: \(currentExerciseInGroup)/\(group.exercises.count), groupIndex: \(currentGroupIndex)/\(totalGroups))")
            #endif
            return canGo
        } else {
            // Standalone: can advance if there are more groups
            let canGo = currentGroupIndex < totalGroups - 1
            #if DEBUG
            print("🔜 Can go to next (standalone): \(canGo) (groupIndex: \(currentGroupIndex)/\(totalGroups))")
            #endif
            return canGo
        }
    }
    
    private var nextButtonTitle: String {
        if let nextExercise = nextExerciseInSuperset {
            return "Next: \(nextExercise.name ?? "Exercise")"
        } else if currentGroupIndex < exerciseGroups.count - 1 {
            return "Next Exercise"
        } else {
            return "Finish Workout"
        }
    }
    
    private var workoutProgress: Double {
        let totalGroups = Double(exerciseGroups.count)
        guard totalGroups > 0 else { return 0 }
        
        let completedGroups = Double(currentGroupIndex)
        let currentGroupProgress = if let group = currentGroup {
            Double(currentExerciseInGroup) / Double(group.exercises.count)
        } else {
            0.0
        }
        
        return (completedGroups + currentGroupProgress) / totalGroups
    }
    
    private var progressDescription: String {
        if let group = currentGroup {
            if group.isSuperset {
                let exercisePosition = currentExerciseInGroup + 1
                let totalInGroup = group.exercises.count
                return "\(group.displayTitle) - Exercise \(exercisePosition) of \(totalInGroup)"
            } else {
                return "Exercise \(currentGroupIndex + 1) of \(exerciseGroups.count)"
            }
        }
        return "Loading..."
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayTemplate.name ?? "Workout")
                                .font(.title2)
                                .bold()
                            
                            // Prominent Training Day Timer
                            HStack(spacing: 4) {
                                Image(systemName: "stopwatch")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text(formatWorkoutTime())
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.green)
                                    .animation(.none, value: workoutElapsedTime)
                                
                                Text("workout time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            // Bodyweight button
                            Button(action: {
                                showingBodyweightInput = true
                            }) {
                                Image(systemName: "person.crop.circle")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                            }
                            
                            // Sleep tracking button
                            Button(action: {
                                showingSleepInput = true
                            }) {
                                Image(systemName: trainingSession.sleepHours > 0 ? "moon.stars.fill" : "moon.stars")
                                    .foregroundColor(trainingSession.sleepHours > 0 ? .blue : .gray)
                                    .font(.title2)
                            }
                            
                            Button("Finish") {
                                showingFinishAlert = true
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    
                    // Progress bar
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: UIScreen.main.bounds.width * 0.8 * workoutProgress, height: 8)
                        .animation(.easeInOut, value: workoutProgress)
                    
                    HStack {
                        Text(progressDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Smaller secondary time display
                        Text("Started at \(formatStartTime())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Current exercise
                if let exercise = currentExercise {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Exercise info with superset context
                            VStack(spacing: 8) {
                                // Superset indicator
                                if isInSuperset, let group = currentGroup {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        
                                        Text(group.displayTitle)
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.orange)
                                        
                                        if let label = exercise.supersetLabel {
                                            Text(label)
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.white)
                                                .frame(width: 20, height: 20)
                                                .background(Color.orange)
                                                .clipShape(Circle())
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(12)
                                }
                                
                                Text(exercise.name ?? "Exercise")
                                    .font(.title)
                                    .bold()
                                
                                Text(exercise.muscleGroup ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                                
                                if let notes = exercise.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                // Superset flow indicator
                                if isInSuperset, let nextExercise = nextExerciseInSuperset {
                                    VStack(spacing: 4) {
                                        Image(systemName: "arrow.down")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        
                                        Text("Next: \(nextExercise.name ?? "Exercise")")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding()
                            
                            // Sets
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Sets")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    // Add/Remove set buttons
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            removeSet()
                                        }) {
                                            Image(systemName: "minus.circle")
                                                .foregroundColor(.red)
                                                .font(.title2)
                                        }
                                        .disabled(getSetsForCurrentExercise().count <= 1)
                                        
                                        Button(action: {
                                            addSet()
                                        }) {
                                            Image(systemName: "plus.circle")
                                                .foregroundColor(.green)
                                                .font(.title2)
                                        }
                                    }
                                }
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(getSetsForCurrentExercise()) { set in
                                        SetRowView(set: set, setNumber: Int(set.order) + 1) {
                                            // Auto-start rest timer when any set is completed
                                            startRestTimer()
                                        }
                                    }
                                }
                            }
                            .padding()
                            
                            // Rest Timer Section
                            if restTimerActive {
                                RestTimerView(
                                    timeRemaining: $restTimeRemaining,
                                    defaultTime: $defaultRestTime,
                                    isActive: $restTimerActive,
                                    onSettingsPressed: {
                                        showingRestSettings = true
                                    },
                                    onSkipPressed: {
                                        skipRest()
                                    },
                                    onPausePressed: {
                                        pauseRest()
                                    },
                                    onResetPressed: {
                                        resetRest()
                                    }
                                )
                                .padding()
                                .onReceive(restTimer) { _ in
                                    updateRestTimer()
                                }
                            }
                            
                            // Navigation buttons
                            HStack(spacing: 20) {
                                if canGoToPreviousExercise {
                                    Button("Previous") {
                                        goToPreviousExercise()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                }
                                
                                if canGoToNextExercise {
                                    Button(nextButtonTitle) {
                                        goToNextExercise()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(nextExerciseInSuperset != nil ? Color.orange : (currentGroupIndex < exerciseGroups.count - 1 ? Color.orange : Color.green))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                } else {
                                    Button("Finish Workout") {
                                        showingFinishAlert = true
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    Text("No exercises in this workout")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            setupWorkoutSession()
            loadRestTimerSettings()
        }
        .onReceive(workoutTimer) { _ in
            updateWorkoutTime()
        }
        .alert("Finish Workout?", isPresented: $showingFinishAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Finish") {
                finishWorkout()
            }
        } message: {
            Text("Are you sure you want to finish this workout? Your progress will be saved.")
        }
        .sheet(isPresented: $showingSleepInput) {
            SleepInputView(trainingSession: trainingSession)
        }
        .sheet(isPresented: $showingBodyweightInput) {
            BodyweightInputView(trainingSession: trainingSession)
        }
        .sheet(isPresented: $showingRestSettings) {
            RestTimerSettingsView(defaultRestTime: $defaultRestTime)
        }
    }
    
    // MARK: - Navigation Methods
    
    private func goToPreviousExercise() {
        withAnimation {
            if currentExerciseInGroup > 0 {
                // Go to previous exercise in current group
                currentExerciseInGroup -= 1
            } else if currentGroupIndex > 0 {
                // Go to previous group
                currentGroupIndex -= 1
                // Go to last exercise in the previous group
                if let previousGroup = exerciseGroups[safe: currentGroupIndex] {
                    currentExerciseInGroup = previousGroup.exercises.count - 1
                }
            }
        }
    }
    
    private func goToNextExercise() {
        withAnimation {
            if let group = currentGroup, group.isSuperset {
                // In superset: advance within group or move to next group
                if currentExerciseInGroup < group.exercises.count - 1 {
                    currentExerciseInGroup += 1
                } else {
                    // Move to next group
                    currentGroupIndex += 1
                    currentExerciseInGroup = 0
                }
            } else {
                // Standalone exercise: move to next group
                currentGroupIndex += 1
                currentExerciseInGroup = 0
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupWorkoutSession() {
        #if DEBUG
        print("Setting up workout session...")
        #endif
        
        // Create completed exercises for each template
        for exerciseTemplate in dayTemplate.sortedExerciseTemplates {
            #if DEBUG
            print("Creating completed exercise for: \(exerciseTemplate.name ?? "unknown")")
            #endif
            
            let completedExercise = CompletedExercise(context: viewContext)
            completedExercise.template = exerciseTemplate
            completedExercise.session = trainingSession
            
            // Create sets based on target sets
            #if DEBUG
            print("Creating \(exerciseTemplate.targetSets) sets")
            #endif
            for setIndex in 0..<exerciseTemplate.targetSets {
                let exerciseSet = ExerciseSet(context: viewContext)
                exerciseSet.order = Int16(setIndex)
                exerciseSet.weight = 0
                exerciseSet.reps = 0
                exerciseSet.isCompleted = false
                exerciseSet.completedExercise = completedExercise
                
                // Also add to the other side of the relationship
                completedExercise.addToExerciseSets(exerciseSet)
                
                #if DEBUG
                print("Created set \(setIndex + 1)")
                #endif
            }
        }
        
        do {
            try viewContext.save()
            #if DEBUG
            print("Workout session saved successfully")
            #endif
            
            // Refresh the training session to pick up the new relationships
            viewContext.refresh(trainingSession, mergeChanges: true)
        } catch {
            #if DEBUG
            print("Error setting up workout: \(error)")
            #endif
        }
    }
    
    private func getSetsForCurrentExercise() -> [ExerciseSet] {
        // Force refresh by accessing the trigger (SwiftUI will re-evaluate when this changes)
        _ = refreshTrigger
        
        guard let completed = completedExercise else { 
            #if DEBUG
            print("No completed exercise found for current exercise")
            #endif
            return [] 
        }
        
        // Refresh the completed exercise to get latest data
        viewContext.refresh(completed, mergeChanges: true)
        
        let sets = completed.sets
        #if DEBUG
        print("Found \(sets.count) sets for \(completed.template?.name ?? "unknown")")
        #endif
        return sets
    }
    
    private func formatWorkoutTime() -> String {
        let totalSeconds = Int(workoutElapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        } else {
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
    }
    
    private func updateWorkoutTime() {
        guard let startTime = trainingSession.startTime else { return }
        workoutElapsedTime = Date().timeIntervalSince(startTime)
    }
    
    private func formatStartTime() -> String {
        guard let startTime = trainingSession.startTime else {
            return "N/A"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: startTime)
    }
    
    // MARK: - Rest Timer Methods
    
    private func startRestTimer() {
        restTimeRemaining = defaultRestTime
        restTimerActive = true
        
        #if DEBUG
        print("⏰ Started rest timer: \(Int(defaultRestTime))s")
        #endif
    }
    
    private func updateRestTimer() {
        guard restTimerActive else { return }
        
        if restTimeRemaining > 0 {
            restTimeRemaining -= 1
            
            // Warning haptic at 10 seconds remaining
            if restTimeRemaining == 10 {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                #if DEBUG
                print("⚠️ Rest timer: 10 seconds remaining")
                #endif
            }
            
            // Final countdown haptic at 3, 2, 1
            if restTimeRemaining <= 3 && restTimeRemaining > 0 {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                #if DEBUG
                print("⏰ Rest timer countdown: \(Int(restTimeRemaining))")
                #endif
            }
        } else {
            // Rest time completed
            restTimerActive = false
            
            // Strong completion haptic feedback (3 pulses)
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }
            
            #if DEBUG
            print("✅ Rest timer completed! Ready for next set")
            #endif
        }
    }
    
    private func pauseRest() {
        restTimerActive = false
        #if DEBUG
        print("⏸️ Rest timer paused")
        #endif
    }
    
    private func resetRest() {
        restTimeRemaining = defaultRestTime
        restTimerActive = true
        #if DEBUG
        print("🔄 Rest timer reset to \(Int(defaultRestTime))s")
        #endif
    }
    
    private func skipRest() {
        restTimerActive = false
        restTimeRemaining = 0
        #if DEBUG
        print("⏭️ Rest timer skipped")
        #endif
    }
    
    private func addSet() {
        guard let completed = completedExercise else { return }
        
        let newSet = ExerciseSet(context: viewContext)
        let currentSets = completed.sets
        newSet.order = Int16(currentSets.count)
        newSet.weight = 0
        newSet.reps = 0
        newSet.isCompleted = false
        newSet.completedExercise = completed
        
        completed.addToExerciseSets(newSet)
        
        do {
            try viewContext.save()
            refreshTrigger += 1 // Trigger UI update
        } catch {
            #if DEBUG
            print("Error adding set: \(error)")
            #endif
        }
    }
    
    private func removeSet() {
        guard let completed = completedExercise else { return }
        let sets = completed.sets
        guard sets.count > 1 else { return } // Don't allow removing the last set
        
        // Remove the last set
        if let lastSet = sets.last {
            completed.removeFromExerciseSets(lastSet)
            viewContext.delete(lastSet)
            
            do {
                try viewContext.save()
                refreshTrigger += 1 // Trigger UI update
            } catch {
                #if DEBUG
                print("Error removing set: \(error)")
                #endif
            }
        }
    }
    
    private func finishWorkout() {
        isFinishing = true
        
        // Set end time
        let endTime = Date()
        trainingSession.setValue(endTime, forKey: "endTime")
        
        do {
            try viewContext.save()
            #if DEBUG
            print("Workout finished and saved - Duration: \(trainingSession.durationFormatted)")
            #endif
            dismiss()
        } catch {
            #if DEBUG
            print("Error finishing workout: \(error)")
            #endif
            isFinishing = false
        }
    }
    
    private func loadRestTimerSettings() {
        let savedTime = UserDefaults.standard.double(forKey: "defaultRestTime")
        if savedTime > 0 {
            defaultRestTime = savedTime
            #if DEBUG
            print("Loaded default rest time from UserDefaults: \(Int(savedTime))s")
            #endif
        } else {
            #if DEBUG
            print("No default rest time found in UserDefaults, using default: \(Int(defaultRestTime))s")
            #endif
        }
        
        // Initialize workout timer immediately
        updateWorkoutTime()
        
        #if DEBUG
        print("⏱️ Live workout timer initialized")
        #endif
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Set Row View (unchanged)

struct SetRowView: View {
    @ObservedObject var set: ExerciseSet
    @State private var weightString = ""
    @State private var repsString = ""
    
    let setNumber: Int
    var onSetCompleted: (() -> Void)? = nil
    
    var setIsCompleted: Bool {
        return set.hasValidWeight && set.reps > 0
    }
    
    var bodyweightDisplay: String {
        let bodyweight = set.session?.userBodyweight ?? UserDefaults.standard.double(forKey: "defaultBodyweight") != 0 ? UserDefaults.standard.double(forKey: "defaultBodyweight") : 70.0
        let total = bodyweight + set.extraWeight
        if set.extraWeight > 0 {
            return "\(Int(bodyweight))kg + \(Int(set.extraWeight))kg = \(Int(total))kg"
        } else {
            return "\(Int(bodyweight))kg"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Set number
                Text("\(setNumber)")
                    .font(.headline)
                    .frame(width: 30)
                    .foregroundColor(setIsCompleted ? .white : .primary)
                    .background(setIsCompleted ? Color.green : Color.gray.opacity(0.3))
                    .clipShape(Circle())
                
                // Bodyweight toggle
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bodyweight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("", isOn: Binding(
                        get: { set.isBodyweight },
                        set: { newValue in
                            set.isBodyweight = newValue
                            if newValue {
                                // Clear regular weight when switching to bodyweight
                                set.weight = 0
                                weightString = ""
                            } else {
                                // Clear extra weight when switching away from bodyweight
                                set.extraWeight = 0
                                weightString = ""
                            }
                            updateCompletionStatus()
                            saveContext()
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.8)
                }
                
                // Weight/Extra Weight input
                VStack(alignment: .leading, spacing: 2) {
                    Text(set.isBodyweight ? "Extra (kg)" : "Weight (kg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("0", text: $weightString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .onChange(of: weightString) { newValue in
                            // Input validation: only allow positive numbers up to 999.9
                            let filteredValue = newValue.filter { $0.isNumber || $0 == "." }
                            if filteredValue != newValue {
                                weightString = filteredValue
                                return
                            }
                            
                            let weightValue = min(Double(filteredValue) ?? 0, 999.9)
                            if set.isBodyweight {
                                set.extraWeight = weightValue
                            } else {
                                set.weight = weightValue
                            }
                            updateCompletionStatus()
                            saveContext()
                        }
                }
                
                Text("×")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                // Reps input
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("0", text: $repsString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                        .onChange(of: repsString) { newValue in
                            // Input validation: only allow numbers up to 999
                            let filteredValue = newValue.filter { $0.isNumber }
                            if filteredValue != newValue {
                                repsString = filteredValue
                                return
                            }
                            
                            let repsValue = min(Int(filteredValue) ?? 0, 999)
                            set.reps = Int16(repsValue)
                            updateCompletionStatus()
                            saveContext()
                        }
                }
                
                Spacer()
            }
            
            // Show effective weight for bodyweight exercises
            if set.isBodyweight {
                HStack {
                    Text("Total: \(bodyweightDisplay)")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.leading, 42) // Align with weight input
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            updateWeightDisplay()
            repsString = set.reps > 0 ? String(set.reps) : ""
        }
    }
    
    private func updateWeightDisplay() {
        if set.isBodyweight {
            weightString = set.extraWeight > 0 ? String(set.extraWeight) : ""
        } else {
            weightString = set.weight > 0 ? String(set.weight) : ""
        }
    }
    
    private func updateCompletionStatus() {
        let wasCompleted = set.isCompleted
        let isNowCompleted = setIsCompleted
        set.isCompleted = isNowCompleted
        
        // Auto-start rest timer when set becomes completed
        if !wasCompleted && isNowCompleted {
            #if DEBUG
            print("🎯 Set completed! Triggering rest timer")
            #endif
            onSetCompleted?()
        }
    }
    
    private func saveContext() {
        do {
            try set.managedObjectContext?.save()
        } catch {
            #if DEBUG
            print("Error saving set: \(error)")
            #endif
        }
    }
}

struct WorkoutSessionView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let dayTemplate = TrainingDayTemplate(context: context)
        dayTemplate.name = "Push Day"
        
        let session = TrainingSession(context: context)
        session.date = Date()
        
        return WorkoutSessionView(dayTemplate: dayTemplate, trainingSession: session)
            .environment(\.managedObjectContext, context)
    }
}

// MARK: - Rest Timer Component

struct RestTimerView: View {
    @Binding var timeRemaining: TimeInterval
    @Binding var defaultTime: TimeInterval
    @Binding var isActive: Bool
    
    let onSettingsPressed: () -> Void
    let onSkipPressed: () -> Void
    let onPausePressed: () -> Void
    let onResetPressed: () -> Void
    
    private var timeDisplay: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var progressPercentage: Double {
        guard defaultTime > 0 else { return 0 }
        return (defaultTime - timeRemaining) / defaultTime
    }
    
    private var timerColor: Color {
        if timeRemaining <= 10 {
            return .red
        } else if timeRemaining <= 30 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Timer Header
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(timerColor)
                    .font(.title2)
                
                Text("Rest Time")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onSettingsPressed) {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            
            // Large Timer Display
            VStack(spacing: 8) {
                Text(timeDisplay)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
                    .animation(.easeInOut(duration: 0.3), value: timerColor)
                
                // Progress Bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(timerColor)
                        .frame(width: UIScreen.main.bounds.width * 0.8 * progressPercentage, height: 8)
                        .animation(.linear(duration: 0.1), value: progressPercentage)
                }
                .frame(width: UIScreen.main.bounds.width * 0.8)
                
                Text("Rest between sets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Timer Controls
            HStack(spacing: 20) {
                // Reset Button
                Button(action: onResetPressed) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Pause/Resume Button
                Button(action: onPausePressed) {
                    HStack(spacing: 4) {
                        Image(systemName: isActive ? "pause.fill" : "play.fill")
                        Text(isActive ? "Pause" : "Resume")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Skip Button
                Button(action: onSkipPressed) {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                        Text("Skip")
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Rest Timer Settings

struct RestTimerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var defaultRestTime: TimeInterval
    
    @State private var selectedTime: TimeInterval
    
    let restTimeOptions: [TimeInterval] = [30, 45, 60, 75, 90, 105, 120, 150, 180, 240, 300]
    
    init(defaultRestTime: Binding<TimeInterval>) {
        self._defaultRestTime = defaultRestTime
        self._selectedTime = State(initialValue: defaultRestTime.wrappedValue)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "timer.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Rest Timer Settings")
                        .font(.title2)
                        .bold()
                    
                    Text("Choose your default rest time between sets")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Current Setting")
                        .font(.headline)
                    
                    HStack {
                        Text("Rest Time:")
                        Spacer()
                        Text(formatTime(selectedTime))
                            .font(.title3)
                            .bold()
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Text("Quick Select")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(restTimeOptions, id: \.self) { time in
                            Button(action: {
                                selectedTime = time
                            }) {
                                VStack(spacing: 4) {
                                    Text(formatTime(time))
                                        .font(.headline)
                                        .bold()
                                    
                                    if time == 90 {
                                        Text("Default")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .foregroundColor(selectedTime == time ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(selectedTime == time ? Color.blue : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Tips")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• 60-90s: Strength training")
                            Text("• 90-120s: Heavy compound movements")
                            Text("• 45-60s: Hypertrophy/muscle building")
                            Text("• 30-45s: Endurance/light weights")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button("Save Settings") {
                    defaultRestTime = selectedTime
                    UserDefaults.standard.set(selectedTime, forKey: "defaultRestTime")
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
            }
            .padding()
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Load saved setting
            let savedTime = UserDefaults.standard.double(forKey: "defaultRestTime")
            if savedTime > 0 {
                selectedTime = savedTime
                defaultRestTime = savedTime
            }
        }
    }
} 