import SwiftUI
import CoreData
import Combine
import UserNotifications

// MARK: - Shared Focus Key For Set Inputs
enum EditingFocus: Hashable {
    case weight(String) // NSManagedObjectID URI
    case reps(String)
}

struct WorkoutSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    let dayTemplate: TrainingDayTemplate
    @ObservedObject var trainingSession: TrainingSession
    
    @State private var currentGroupIndex = 0
    @State private var currentExerciseInGroup = 0
    @State private var showingFinishAlert = false
    @State private var isFinishing = false
    // @State private var refreshTrigger = 0 // REMOVED - was causing unnecessary UI refreshes
    @State private var showingSleepInput = false
    @State private var showingBodyweightInput = false
    @State private var showingNutritionInput = false
    @State private var workoutElapsedTime: TimeInterval = 0
    
    // Rest Timer State
    @State private var restTimeRemaining: TimeInterval = 0
    @State private var restTimerActive = false
    @State private var defaultRestTime: TimeInterval = 90 // 90 seconds default
    
    // Computed property for real-time display (reduces state updates)
    private var displayRestTime: TimeInterval {
        guard restTimerActive, let endTime = restTimerEndTime else { return restTimeRemaining }
        let currentTime = Date()
        let remainingTime = endTime.timeIntervalSince(currentTime)
        return max(0, remainingTime)
    }
    @State private var showingRestSettings = false
    @State private var showingAddExercise = false
    @State private var showingDeleteConfirmation = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Timer cancellation tokens to prevent memory leaks
    @State private var workoutTimerCancellable: AnyCancellable?
    @State private var restTimerCancellable: AnyCancellable?
    @State private var timersAreRunning = false
    @FocusState private var focusedEditingField: EditingFocus?
    private var editingFocusBinding: Binding<EditingFocus?> {
        Binding(
            get: { focusedEditingField },
            set: { focusedEditingField = $0 }
        )
    }
    
    // Background timer persistence
    @State private var restTimerStartTime: Date?
    @State private var restTimerEndTime: Date?
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid // deprecated usage removed below
    
    // UserDefaults keys for timer persistence
    private let restTimerActiveKey = "restTimerActive"
    private let restTimerStartTimeKey = "restTimerStartTime"
    private let restTimerDurationKey = "restTimerDuration"
    private let restTimerSessionIDKey = "restTimerSessionID"
    
    // Timers are now managed through cancellable tokens for proper cleanup
    
    // MARK: - Workout Navigation Logic
    
    private var exerciseGroups: [ExerciseGroup] {
        let groups = dayTemplate.exerciseGroups
        #if DEBUG
        if groups.isEmpty {
            print("❌ WARNING: No exercise groups found!")
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
        
        #if DEBUG
        print("🔍 Debugging canGoToNextExercise:")
        print("   Current group index: \(currentGroupIndex)")
        print("   Current exercise in group: \(currentExerciseInGroup)")
        print("   Total groups: \(totalGroups)")
        #endif
        
        if let group = currentGroup, group.isSuperset {
            // Superset is handled side-by-side; treat as a single unit
            let canGo = currentGroupIndex < totalGroups - 1
            #if DEBUG
            print("🔜 Can go to next (superset treated as single unit): \(canGo)")
            #endif
            return canGo
        } else {
            // Standalone exercise: can advance if there are more groups
            let canGo = currentGroupIndex < totalGroups - 1
            #if DEBUG
            print("🔜 Can go to next (standalone): \(canGo)")
            print("   - More groups: \(canGo) (\(currentGroupIndex)/\(totalGroups))")
            if let currentGroup = currentGroup {
                print("   - Current group has \(currentGroup.exercises.count) exercises")
            }
            #endif
            return canGo
        }
    }
    
    private var nextButtonTitle: String {
        if let group = currentGroup, group.isSuperset {
            return currentGroupIndex < exerciseGroups.count - 1 ? "Next Exercise" : "Finish Workout"
        }
        if currentGroupIndex < exerciseGroups.count - 1 { return "Next Exercise" }
        return "Finish Workout"
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
    
    // Dynamic exercise deletion logic
    private var canDeleteCurrentExercise: Bool {
        guard let exercise = currentExercise else { return false }
        
        // Only allow deletion if this is one of the last 3 exercises added
        // (assumes recently added exercises are at the end)
        let allExercises = dayTemplate.sortedExerciseTemplates
        guard let exerciseIndex = allExercises.firstIndex(of: exercise) else { return false }
        
        // Allow deletion if it's in the last 3 exercises and we have more than 1 exercise total
        let isInLastThree = exerciseIndex >= max(0, allExercises.count - 3)
        let hasMultipleExercises = allExercises.count > 1
        
        return isInLastThree && hasMultipleExercises
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                exerciseContentSection
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            setupWorkoutSession()
            restoreNavigationStateIfAvailable()
            loadRestTimerSettings()
            requestNotificationPermissions()
            restoreRestTimerIfNeeded()
            startTimersIfNeeded()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: currentGroupIndex) { _ in
            saveNavigationState()
        }
        .onChange(of: currentExerciseInGroup) { _ in
            saveNavigationState()
        }
        .alert("Finish Workout?", isPresented: $showingFinishAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Finish") {
                finishWorkout()
            }
        } message: {
            Text("Are you sure you want to finish this workout? Your progress will be saved.")
        }
        .alert("Delete Exercise?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCurrentExercise()
            }
        } message: {
            Text("Are you sure you want to delete \"\(currentExercise?.name ?? "this exercise")\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showingSleepInput) {
            SleepInputView(trainingSession: trainingSession)
        }
        .sheet(isPresented: $showingNutritionInput) {
            NutritionInputView(trainingSession: trainingSession)
        }
        .sheet(isPresented: $showingBodyweightInput) {
            BodyweightInputView(trainingSession: trainingSession)
        }
        .sheet(isPresented: $showingRestSettings) {
            RestTimerSettingsView(defaultRestTime: $defaultRestTime)
        }
        .sheet(isPresented: $showingAddExercise) {
            QuickAddExerciseView(
                dayTemplate: dayTemplate,
                trainingSession: trainingSession,
                onExerciseAdded: { newExercise in
                    handleNewExerciseAdded(newExercise)
                }
            )
        }
        .onDisappear {
            // Timer management is now handled by scene phase changes
            // No need to stop timers here as they should persist through view changes
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
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
                            
                            // Previous day nutrition button
                            Button(action: {
                                showingNutritionInput = true
                            }) {
                                Image(systemName: trainingSession.proteinGrams > 0 ? "fork.knife.circle.fill" : "fork.knife.circle")
                                    .foregroundColor(trainingSession.proteinGrams > 0 ? .green : .gray)
                                    .font(.title2)
                            }
                            
                            // Add exercise button
                            Button(action: {
                                showingAddExercise = true
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
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
    }
    
    private var exerciseContentSection: some View {
        Group {
            // Current exercise
                if let exercise = currentExercise {
                    ZStack {
                        // Delete background (shows when swiping)
                        if canDeleteCurrentExercise && isDragging && dragOffset < -50 {
                            HStack {
                                Spacer()
                                VStack {
                                    Image(systemName: "trash.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Release to Delete")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .bold()
                                }
                                .padding(.trailing, 30)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.red)
                        }
                        
                        // Main content with swipe gesture
                        ScrollView(.vertical, showsIndicators: true) {
                            exerciseDetailContent(exercise: exercise)
                        }
                        .scrollDismissesKeyboard(.never)
                        .offset(x: dragOffset)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    guard canDeleteCurrentExercise && focusedEditingField == nil else {
                                        isDragging = false
                                        return
                                    }
                                    let horizontalMovement = abs(value.translation.width)
                                    let verticalMovement = abs(value.translation.height)
                                    if horizontalMovement > verticalMovement &&
                                       horizontalMovement > 20 &&
                                       verticalMovement < 30 {
                                        isDragging = true
                                        dragOffset = min(0, value.translation.width)
                                    }
                                }
                                .onEnded { value in
                                    guard canDeleteCurrentExercise && focusedEditingField == nil else {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { dragOffset = 0 }
                                        return
                                    }
                                    isDragging = false
                                    let horizontalMovement = abs(value.translation.width)
                                    let verticalMovement = abs(value.translation.height)
                                    if dragOffset < -100 &&
                                       horizontalMovement > verticalMovement &&
                                       horizontalMovement > 50 {
                                        showingDeleteConfirmation = true
                                    }
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                    }
                                }
                        )
                    } // End ZStack
                } else {
                    Text("No exercises in this workout")
                        .foregroundColor(.secondary)
                }
        }
    }

    // MARK: - Extracted Content Builders

    @ViewBuilder
    private func exerciseDetailContent(exercise: ExerciseTemplate) -> some View {
        VStack(spacing: 20) {
            // Exercise info with superset context
            VStack(spacing: 8) {
                                if isInSuperset, let group = currentGroup, group.exercises.count == 2 {
                                    // Compact superset header to free vertical space
                                    HStack(spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                            Text(group.displayTitle)
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(10)
                                        Spacer()
                                    }
                                    HStack(alignment: .center, spacing: 12) {
                                        let a = group.exercises[0]
                                        let b = group.exercises[1]
                                        VStack(spacing: 4) {
                                            Text(a.name ?? "Exercise A")
                                                .font(.headline)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                            if let mg = a.muscleGroup, !mg.isEmpty {
                                                Text(mg).font(.caption).foregroundColor(.orange)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        VStack(spacing: 4) {
                                            Text(b.name ?? "Exercise B")
                                                .font(.headline)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                            if let mg = b.muscleGroup, !mg.isEmpty {
                                                Text(mg).font(.caption).foregroundColor(.orange)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                } else {
                                    // Original single exercise header
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
                                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Orientation hint for supersets
            if isInSuperset {
                let isPortrait = UIScreen.main.bounds.height >= UIScreen.main.bounds.width
                if isPortrait {
                    HStack(spacing: 8) {
                        Image(systemName: "rotate.right.fill").foregroundColor(.orange)
                        Text("Rotate to landscape to view both exercises side-by-side")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }

            // Sets / Rounds
            if isInSuperset, let group = currentGroup, group.exercises.count == 2 {
                supersetRoundsSection(group: group)
            } else {
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
                        ForEach(getSetsForCurrentExercise(), id: \.objectID) { set in
                            SetRowView(set: set, editingFocus: editingFocusBinding, setNumber: Int(set.order) + 1) {
                                // Auto-start rest timer when any set is completed
                                startRestTimer()
                                // If user completes set N, auto-advance focus to next set's weight field
                                DispatchQueue.main.async {
                                    if let next = getSetsForCurrentExercise().first(where: { Int($0.order) == Int(set.order) + 1 }) {
                                        let id = next.objectID.uriRepresentation().absoluteString
                                        focusedEditingField = .weight(id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            
            // Rest Timer Section (reserve constant height to avoid layout-induced focus loss)
            ZStack {
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
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            
            // Navigation buttons
            VStack(spacing: 12) {
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
                                
                                // Show "Add More" option when on last exercise
                                if !canGoToNextExercise {
                                    VStack(spacing: 8) {
                                        HStack {
                                            Image(systemName: "lightbulb.fill")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                            
                                            Text("Want to add more exercises?")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                        }
                                        
                                        Button(action: {
                                            showingAddExercise = true
                                        }) {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Add Exercise")
                                                    .bold()
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                            .foregroundColor(.white)
                                            .background(Color.blue)
                                            .cornerRadius(10)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
            }
            .padding()
        }
    }

    // MARK: - Superset Rounds Section

    @ViewBuilder
    private func supersetRoundsSection(group: ExerciseGroup) -> some View {
        let exercises = group.exercises
        if exercises.count != 2 {
            EmptyView()
        } else {
            VStack(spacing: 12) {
                HStack {
                    Text("Rounds")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: { removeSupersetRound(group: group) }) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                                .font(.title2)
                        }
                        .disabled(supersetRoundsCount(group: group) <= 1)
                        Button(action: { addSupersetRound(group: group) }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                }

                let a = exercises[0]
                let b = exercises[1]
                let (aCompleted, bCompleted) = (completedExercise(for: a), completedExercise(for: b))
                let rounds = max(aCompleted?.sets.count ?? 0, bCompleted?.sets.count ?? 0)

                VStack(spacing: 8) {
                    ForEach(0..<rounds, id: \.self) { roundIndex in
                        HStack(spacing: 12) {
                            if let setA = setForRound(completed: aCompleted, roundIndex: roundIndex) {
                                SetRowView(set: setA, editingFocus: editingFocusBinding, setNumber: roundIndex + 1) {
                                    // After completing A, focus B's weight in same round
                                    DispatchQueue.main.async {
                                        if let setB = setForRound(completed: bCompleted, roundIndex: roundIndex) {
                                            let id = setB.objectID.uriRepresentation().absoluteString
                                            focusedEditingField = .weight(id)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }

                            if let setB = setForRound(completed: bCompleted, roundIndex: roundIndex) {
                                SetRowView(set: setB, editingFocus: editingFocusBinding, setNumber: roundIndex + 1) {
                                    // After completing B, if both A and B for this round are completed -> start rest
                                    if let setA = setForRound(completed: aCompleted, roundIndex: roundIndex),
                                       setA.isCompleted, setB.isCompleted {
                                        startRestTimer()
                                        // Focus next round's A weight if exists
                                        DispatchQueue.main.async {
                                            if roundIndex + 1 < rounds, let nextA = setForRound(completed: aCompleted, roundIndex: roundIndex + 1) {
                                                let id = nextA.objectID.uriRepresentation().absoluteString
                                                focusedEditingField = .weight(id)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func completedExercise(for template: ExerciseTemplate) -> CompletedExercise? {
        return trainingSession.sortedCompletedExercises.first(where: { $0.template == template })
    }

    private func setForRound(completed: CompletedExercise?, roundIndex: Int) -> ExerciseSet? {
        guard let completed = completed else { return nil }
        if roundIndex < completed.sets.count {
            return completed.sets[roundIndex]
        } else {
            // Create missing set for this round
            let exerciseSet = ExerciseSet(context: viewContext)
            exerciseSet.order = Int16(roundIndex)
            exerciseSet.weight = 0
            exerciseSet.reps = 0
            exerciseSet.isCompleted = false
            exerciseSet.completedExercise = completed
            completed.addToExerciseSets(exerciseSet)
            do { try viewContext.save() } catch { }
            return exerciseSet
        }
    }

    private func supersetRoundsCount(group: ExerciseGroup) -> Int {
        let exercises = group.exercises
        guard exercises.count == 2 else { return getSetsForCurrentExercise().count }
        let aCount = completedExercise(for: exercises[0])?.sets.count ?? 0
        let bCount = completedExercise(for: exercises[1])?.sets.count ?? 0
        return max(aCount, bCount)
    }

    private func addSupersetRound(group: ExerciseGroup) {
        guard group.exercises.count == 2 else { return }
        let a = group.exercises[0]
        let b = group.exercises[1]
        guard let aCompleted = completedExercise(for: a), let bCompleted = completedExercise(for: b) else { return }
        let nextIndex = max(aCompleted.sets.count, bCompleted.sets.count)
        func createSet(for completed: CompletedExercise, index: Int) {
            let s = ExerciseSet(context: viewContext)
            s.order = Int16(index)
            s.weight = 0
            s.reps = 0
            s.isCompleted = false
            s.completedExercise = completed
            completed.addToExerciseSets(s)
        }
        createSet(for: aCompleted, index: nextIndex)
        createSet(for: bCompleted, index: nextIndex)
        do { try viewContext.save() } catch { }
    }

    private func removeSupersetRound(group: ExerciseGroup) {
        guard group.exercises.count == 2 else { return }
        let a = group.exercises[0]
        let b = group.exercises[1]
        guard let aCompleted = completedExercise(for: a), let bCompleted = completedExercise(for: b) else { return }
        let lastIndex = min(aCompleted.sets.count, bCompleted.sets.count) - 1
        guard lastIndex >= 1 else { return }
        if let lastA = aCompleted.sets.last { aCompleted.removeFromExerciseSets(lastA); viewContext.delete(lastA) }
        if let lastB = bCompleted.sets.last { bCompleted.removeFromExerciseSets(lastB); viewContext.delete(lastB) }
        do { try viewContext.save() } catch { }
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
                // Superset handled as one step: jump to next group
                currentGroupIndex += 1
                currentExerciseInGroup = 0
            } else {
                // Standalone exercise: move to next group
                currentGroupIndex += 1
                currentExerciseInGroup = 0
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupWorkoutSession() {
        // Ensure idempotency: only create missing CompletedExercises/sets
        // Map existing completed exercises by template ID (avoid NSManagedObject as Dictionary key)
        let existingByTemplateId: [String: CompletedExercise] = Dictionary(uniqueKeysWithValues: trainingSession.sortedCompletedExercises.compactMap { completed in
            guard let template = completed.template else { return nil }
            return (template.objectID.uriRepresentation().absoluteString, completed)
        })

        for exerciseTemplate in dayTemplate.sortedExerciseTemplates {
            let completedExercise: CompletedExercise
            let templateId = exerciseTemplate.objectID.uriRepresentation().absoluteString
            if let existing = existingByTemplateId[templateId] {
                completedExercise = existing
            } else {
                let newCompleted = CompletedExercise(context: viewContext)
                newCompleted.template = exerciseTemplate
                newCompleted.session = trainingSession
                completedExercise = newCompleted
            }

            // Ensure sets exist up to targetSets without duplicating
            let currentSets = completedExercise.sets
            let targetSetCount = Int(exerciseTemplate.targetSets)
            if currentSets.count < targetSetCount {
                for setIndex in currentSets.count..<targetSetCount {
                    let exerciseSet = ExerciseSet(context: viewContext)
                    exerciseSet.order = Int16(setIndex)
                    exerciseSet.weight = 0
                    exerciseSet.reps = 0
                    exerciseSet.isCompleted = false
                    exerciseSet.completedExercise = completedExercise
                    completedExercise.addToExerciseSets(exerciseSet)
                }
            }
        }

        do {
            try viewContext.save()
            viewContext.refresh(trainingSession, mergeChanges: true)
        } catch {
            #if DEBUG
            print("Error setting up workout: \(error)")
            #endif
        }
    }
    
    private func getSetsForCurrentExercise() -> [ExerciseSet] {
        guard let completed = completedExercise else { 
            #if DEBUG
            print("No completed exercise found for current exercise")
            #endif
            return [] 
        }
        
        // Return sets directly - no aggressive refreshing needed
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
        let currentTime = Date()
        restTimerStartTime = currentTime
        restTimerEndTime = currentTime.addingTimeInterval(defaultRestTime)
        restTimeRemaining = defaultRestTime
        restTimerActive = true
        
        // Start the UI timer immediately
        if restTimerCancellable == nil {
            setRestTimerFrequency(0.5)
        }
        
        // Persist timer state to UserDefaults
        saveRestTimerState()
        
        // Schedule local notification for timer completion
        scheduleRestTimerNotification()
        
        // No background task; rely on local notification + restore on resume
        
        #if DEBUG
        print("⏰ Started rest timer: \(Int(defaultRestTime))s")
        print("⏰ Timer will end at: \(restTimerEndTime?.description ?? "unknown")")
        #endif
    }
    
    private func updateRestTimer() {
        guard restTimerActive, let endTime = restTimerEndTime else { return }
        
        let currentTime = Date()
        let remainingTime = endTime.timeIntervalSince(currentTime)
        
        if remainingTime > 0 {
            // Only update UI state if the displayed second has changed (reduces re-renders)
            let newDisplayTime = max(0, remainingTime)
            let currentDisplaySecond = Int(restTimeRemaining)
            let newDisplaySecond = Int(newDisplayTime)
            
            if newDisplaySecond != currentDisplaySecond {
                restTimeRemaining = newDisplayTime
                
                // Warning haptic at 10 seconds remaining (only once)
                if newDisplaySecond == 10 {
                    if scenePhase == .active {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    #if DEBUG
                    print("⚠️ Rest timer: 10 seconds remaining")
                    #endif
                }
                
                // Final countdown haptic at 3, 2, 1 (only once per second)
                if newDisplaySecond <= 3 && newDisplaySecond > 0 {
                    if scenePhase == .active {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                    #if DEBUG
                    print("⏰ Rest timer countdown: \(newDisplaySecond)")
                    #endif
                }
            }
        } else {
            // Rest time completed
            completeRestTimer()
        }
    }
    
    private func pauseRest() {
        if restTimerActive {
            // Save current remaining time when pausing
            restTimeRemaining = max(0, restTimerEndTime?.timeIntervalSince(Date()) ?? 0)
        }
        restTimerActive = false
        
        // Stop the rest timer UI updates
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        
        clearRestTimerState()
        cancelRestTimerNotification()
        // No background task to end
        
        #if DEBUG
        print("⏸️ Rest timer paused with \(Int(restTimeRemaining))s remaining")
        #endif
    }
    
    private func resetRest() {
        let currentTime = Date()
        restTimerStartTime = currentTime
        restTimerEndTime = currentTime.addingTimeInterval(defaultRestTime)
        restTimeRemaining = defaultRestTime
        restTimerActive = true
        
        // Start the UI timer immediately
        if restTimerCancellable == nil {
            setRestTimerFrequency(0.5)
        }
        
        // Update persistence and notifications
        saveRestTimerState()
        scheduleRestTimerNotification()
        // No background task; rely on notification + restore
        
        #if DEBUG
        print("🔄 Rest timer reset to \(Int(defaultRestTime))s")
        #endif
    }
    
    private func skipRest() {
        restTimerActive = false
        restTimeRemaining = 0
        
        // Stop the rest timer UI updates
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        
        clearRestTimerState()
        cancelRestTimerNotification()
        // No background task to end
        
        #if DEBUG
        print("⏭️ Rest timer skipped")
        #endif
    }
    
    // MARK: - Timer Completion and Restoration
    
    private func completeRestTimer() {
        // Preserve any active editing focus; do NOT nil it here
        restTimerActive = false
        restTimeRemaining = 0
        
        // Stop the rest timer UI updates
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        
        clearRestTimerState()
        cancelRestTimerNotification()
        // No background task to end
        
        // Strong completion haptic feedback (3 pulses)
        if scenePhase == .active {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if scenePhase == .active {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if scenePhase == .active {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }
            }
        }
        
        #if DEBUG
        print("✅ Rest timer completed! (focus preserved: \(String(describing: focusedEditingField)))")
        #endif
    }
    
    // MARK: - Rest Timer Frequency Management
    
    private func setRestTimerFrequency(_ interval: TimeInterval) {
        guard restTimerActive else { return }
        
        // Properly clean up existing timer
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        
        // Create new timer with specified frequency
        restTimerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                updateRestTimer()
            }
        
        #if DEBUG
        print("🔄 Rest timer frequency changed to \(interval)s")
        #endif
    }
    
    // MARK: - Timer State Persistence
    
    private func saveRestTimerState() {
        guard let startTime = restTimerStartTime else { return }
        // Ensure we have a permanent object ID so we can reliably restore later
        if trainingSession.objectID.isTemporaryID {
            do {
                try viewContext.obtainPermanentIDs(for: [trainingSession])
            } catch {
                #if DEBUG
                print("❌ Failed to obtain permanent ID for session: \(error)")
                #endif
            }
        }
        let sessionID = trainingSession.objectID.uriRepresentation().absoluteString
        
        UserDefaults.standard.set(true, forKey: restTimerActiveKey)
        UserDefaults.standard.set(startTime, forKey: restTimerStartTimeKey)
        UserDefaults.standard.set(defaultRestTime, forKey: restTimerDurationKey)
        UserDefaults.standard.set(sessionID, forKey: restTimerSessionIDKey)
        
        #if DEBUG
        print("💾 Saved rest timer state: active=true, duration=\(defaultRestTime)s")
        #endif
    }
    
    private func clearRestTimerState() {
        UserDefaults.standard.removeObject(forKey: restTimerActiveKey)
        UserDefaults.standard.removeObject(forKey: restTimerStartTimeKey)
        UserDefaults.standard.removeObject(forKey: restTimerDurationKey)
        UserDefaults.standard.removeObject(forKey: restTimerSessionIDKey)
        
        #if DEBUG
        print("🗑️ Cleared rest timer state")
        #endif
    }
    
    private func restoreRestTimerIfNeeded() {
        let isActive = UserDefaults.standard.bool(forKey: restTimerActiveKey)
        guard isActive,
              let savedSessionID = UserDefaults.standard.string(forKey: restTimerSessionIDKey),
              let startTime = UserDefaults.standard.object(forKey: restTimerStartTimeKey) as? Date else {
            // Clear invalid timer state
            clearRestTimerState()
            return
        }
        
        let currentSessionID = trainingSession.objectID.uriRepresentation().absoluteString
        guard savedSessionID == currentSessionID else {
            // Clear invalid timer state for different session
            clearRestTimerState()
            return
        }
        
        let duration = UserDefaults.standard.double(forKey: restTimerDurationKey)
        let endTime = startTime.addingTimeInterval(duration)
        let currentTime = Date()
        let remainingTime = endTime.timeIntervalSince(currentTime)
        
        if remainingTime > 0 {
            // Timer is still running
            restTimerStartTime = startTime
            restTimerEndTime = endTime
            restTimeRemaining = remainingTime
            restTimerActive = true
            
            // Re-schedule notification if needed
            scheduleRestTimerNotification()
            // No background task; rely on notification + restore
            
            #if DEBUG
            print("🔄 Restored rest timer: \(Int(remainingTime))s remaining")
            #endif
        } else {
            // Timer has already completed
            completeRestTimer()
        }
    }
    
    // MARK: - Local Notifications
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    #if DEBUG
                    print("🔔 Notification permissions granted")
                    #endif
                } else {
                    #if DEBUG
                    print("🚫 Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
                    #endif
                }
            }
        }
    }
    
    private func scheduleRestTimerNotification() {
        guard let endTime = restTimerEndTime else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Rest Timer Complete"
        content.body = "Your rest period is over. Time for your next set!"
        content.sound = .default
        content.categoryIdentifier = "REST_TIMER"
        
        // Add user info to help with navigation when notification is tapped
        // Ensure permanent ID for reliability
        if trainingSession.objectID.isTemporaryID {
            do { try viewContext.obtainPermanentIDs(for: [trainingSession]) } catch { }
        }
        let sessionID = trainingSession.objectID.uriRepresentation().absoluteString
        content.userInfo = [
            "type": "rest_timer_complete",
            "sessionID": sessionID
        ]
        
        let timeInterval = endTime.timeIntervalSince(Date())
        guard timeInterval > 0 else { return }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "rest_timer_completion", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                print("❌ Failed to schedule notification: \(error)")
                #endif
            } else {
                #if DEBUG
                print("🔔 Scheduled rest timer notification for \(Int(timeInterval))s")
                #endif
            }
        }
    }
    
    private func cancelRestTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest_timer_completion"])
        #if DEBUG
        print("🔕 Cancelled rest timer notification")
        #endif
    }
    
    // MARK: - Background Task Management
    
    // Background tasks removed to avoid App Store review issues; restoration handles continuity
    
    // MARK: - Dynamic Exercise Management
    
    private func handleNewExerciseAdded(_ exerciseTemplate: ExerciseTemplate) {
        // Create a completed exercise for this new template
        let completedExercise = CompletedExercise(context: viewContext)
        completedExercise.template = exerciseTemplate
        completedExercise.session = trainingSession
        
        // Create sets based on target sets
        for setIndex in 0..<exerciseTemplate.targetSets {
            let exerciseSet = ExerciseSet(context: viewContext)
            exerciseSet.order = Int16(setIndex)
            exerciseSet.weight = 0
            exerciseSet.reps = 0
            exerciseSet.isCompleted = false
            exerciseSet.completedExercise = completedExercise
            
            completedExercise.addToExerciseSets(exerciseSet)
        }
        
        do {
            try viewContext.save()
            
            // Refresh the training session to pick up the new relationships
            viewContext.refresh(trainingSession, mergeChanges: true)
            
            // Navigate to the newly added exercise (it will be the last one)
            let totalGroups = exerciseGroups.count
            if totalGroups > 0 {
                currentGroupIndex = totalGroups - 1
                currentExerciseInGroup = 0
            }
            
            #if DEBUG
            print("✅ Added new exercise: \(exerciseTemplate.name ?? "Unknown") and navigated to it")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error adding new exercise: \(error)")
            #endif
        }
    }
    
    private func deleteCurrentExercise() {
        guard let exercise = currentExercise, canDeleteCurrentExercise else { return }
        
        #if DEBUG
        print("🗑️ Attempting to delete exercise: \(exercise.name ?? "Unknown")")
        #endif
        
        // Find and delete the completed exercise associated with this template
        if let completedExercise = trainingSession.sortedCompletedExercises.first(where: { $0.template == exercise }) {
            // Delete all sets first (avoid force casts)
            if let nsset = completedExercise.exerciseSets, let typedSets = nsset as? Set<ExerciseSet> {
                for set in typedSets {
                    viewContext.delete(set)
                }
            }

            // Delete the completed exercise
            viewContext.delete(completedExercise)
        }
        
        // Delete the exercise template
        viewContext.delete(exercise)
        
        do {
            try viewContext.save()
            
            // Navigate to a safe position
            let remainingExercises = dayTemplate.sortedExerciseTemplates.count - 1 // -1 because we just deleted one
            
            if remainingExercises > 0 {
                // If we deleted the last exercise, go to the previous one
                if currentGroupIndex >= remainingExercises {
                    currentGroupIndex = max(0, remainingExercises - 1)
                    currentExerciseInGroup = 0
                }
                // Otherwise stay where we are (the next exercise will slide into this position)
            } else {
                // This was the last exercise - shouldn't happen due to canDeleteCurrentExercise check
                currentGroupIndex = 0
                currentExerciseInGroup = 0
            }
            
            #if DEBUG
            print("✅ Successfully deleted exercise and navigated to safe position")
            #endif
            
        } catch {
            #if DEBUG
            print("❌ Error deleting exercise: \(error)")
            #endif
        }
    }

    // MARK: - Navigation State Persistence

    private func navigationKey(_ base: String) -> String {
        let sessionID = trainingSession.objectID.uriRepresentation().absoluteString
        return "WorkoutNav.\(base).\(sessionID)"
    }

    private func saveNavigationState() {
        UserDefaults.standard.set(currentGroupIndex, forKey: navigationKey("group"))
        UserDefaults.standard.set(currentExerciseInGroup, forKey: navigationKey("exercise"))
        #if DEBUG
        print("💾 Saved nav state: group=\(currentGroupIndex), exercise=\(currentExerciseInGroup)")
        #endif
    }

    private func restoreNavigationStateIfAvailable() {
        let groupKey = navigationKey("group")
        let exerciseKey = navigationKey("exercise")
        let hasGroup = UserDefaults.standard.object(forKey: groupKey) != nil
        let hasExercise = UserDefaults.standard.object(forKey: exerciseKey) != nil
        guard hasGroup || hasExercise else { return }

        var restoredGroup = UserDefaults.standard.integer(forKey: groupKey)
        var restoredExercise = UserDefaults.standard.integer(forKey: exerciseKey)

        // Clamp to current template bounds
        if exerciseGroups.isEmpty {
            restoredGroup = 0
            restoredExercise = 0
        } else {
            restoredGroup = max(0, min(restoredGroup, max(0, exerciseGroups.count - 1)))
            let exercisesCount = exerciseGroups[safe: restoredGroup]?.exercises.count ?? 0
            restoredExercise = max(0, min(restoredExercise, max(0, exercisesCount - 1)))
        }

        currentGroupIndex = restoredGroup
        currentExerciseInGroup = restoredExercise
        #if DEBUG
        print("🔄 Restored nav state: group=\(currentGroupIndex), exercise=\(currentExerciseInGroup)")
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
            // refreshTrigger += 1 // Trigger UI update - REMOVED
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
                // refreshTrigger += 1 // Trigger UI update - REMOVED
            } catch {
                #if DEBUG
                print("Error removing set: \(error)")
                #endif
            }
        }
    }
    
    private func finishWorkout() {
        isFinishing = true
        
        // Cancel any pending rest timer notifications since workout is ending
        cancelRestTimerNotification()
        
        // Stop and clean up all timers since workout is complete
        if restTimerActive {
            restTimerActive = false
            restTimerCancellable?.cancel()
            restTimerCancellable = nil
            clearRestTimerState()
            // No background task to end
        }
        
        // Set end time
        let endTime = Date()
        trainingSession.setValue(endTime, forKey: "endTime")
        
        do {
            try viewContext.save()
            // Dismiss if presented modally (e.g., from DayTemplateDetailView)
            dismiss()
            // Notify root to unwind back to tabs instead of dismissing a modal
            NotificationCenter.default.post(name: .workoutDidFinish, object: nil)
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
        }
        
        // Initialize workout timer immediately
        updateWorkoutTime()
    }
    
    private func startTimersIfNeeded() {
        // Always start workout timer if not running
        if workoutTimerCancellable == nil {
            workoutTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    updateWorkoutTime()
                }
            #if DEBUG
            print("🔄 Workout timer started")
            #endif
        }
        
        // Start rest timer if not running and rest is active
        if restTimerCancellable == nil && restTimerActive {
            setRestTimerFrequency(0.5)
            #if DEBUG
            print("🔄 Rest timer started via startTimersIfNeeded")
            #endif
        }
        
        timersAreRunning = (workoutTimerCancellable != nil || restTimerCancellable != nil)
        
        #if DEBUG
        print("🔄 Timers setup complete - workout: \(workoutTimerCancellable != nil), rest: \(restTimerCancellable != nil), timersAreRunning: \(timersAreRunning)")
        #endif
    }
    
    private func stopTimersIfRunning() {
        guard timersAreRunning else { return }
        
        workoutTimerCancellable?.cancel()
        workoutTimerCancellable = nil
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        timersAreRunning = false
        
        #if DEBUG
        print("⏹️ Timers stopped and cleaned up")
        #endif
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active - restore timer state and restart UI timers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                restoreRestTimerIfNeeded()
                startTimersIfNeeded()
            }
            #if DEBUG
            print("📱 App became active - restoring timer state and restarting UI timers")
            #endif
            
        case .inactive, .background:
            // App went to background - keep rest timer running, only stop workout timer
            DispatchQueue.main.async {
                if timersAreRunning {
                    // Stop the workout timer and set to nil so it can be restarted later
                    workoutTimerCancellable?.cancel()
                    workoutTimerCancellable = nil
                    
                    // Keep rest timer running but reduce frequency for battery savings
                    if restTimerActive && restTimerCancellable != nil {
                        setRestTimerFrequency(1.0)
                    }
                    #if DEBUG
                    print("📱 App went to background - stopped workout timer, reduced rest timer frequency")
                    #endif
                }
            }
            
        @unknown default:
            break
        }
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
    @State private var saveWorkItem: DispatchWorkItem?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?
    private enum Field { case weight, reps }
    @Binding var editingFocus: EditingFocus?
    private var setIdString: String {
        `set`.objectID.uriRepresentation().absoluteString
    }
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    
    let setNumber: Int
    var onSetCompleted: (() -> Void)? = nil
    
    var setIsCompleted: Bool {
        return set.hasValidWeight && set.reps > 0
    }
    
    var bodyweightDisplay: String {
        let defaultBW = UserDefaults.standard.double(forKey: "defaultBodyweight")
        let fallbackBW = defaultBW != 0 ? defaultBW : 70.0
        let bodyweightKg = set.session?.userBodyweight ?? fallbackBW
        let extraKg = set.extraWeight
        let unit = Units.unitSuffix(weightUnit)
        let bodyweightDisp = Units.kgToDisplay(bodyweightKg, unit: weightUnit)
        let extraDisp = Units.kgToDisplay(extraKg, unit: weightUnit)
        let totalDisp = Units.kgToDisplay(bodyweightKg + extraKg, unit: weightUnit)
        if set.extraWeight > 0 {
            return "\(Int(bodyweightDisp))\(unit) + \(Int(extraDisp))\(unit) = \(Int(totalDisp))\(unit)"
        } else {
            return "\(Int(bodyweightDisp))\(unit)"
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
                            debouncedSave()
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.8)
                }
                
                // Weight/Extra Weight input
                VStack(alignment: .leading, spacing: 2) {
                    Text(set.isBodyweight ? "Extra (\(Units.unitSuffix(weightUnit)))" : "Weight (\(Units.unitSuffix(weightUnit)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("0", text: $weightString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .focused($focusedField, equals: .weight)
                        .onTapGesture {
                            focusedField = .weight
                            editingFocus = .weight(setIdString)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                withAnimation(.none) {
                                    focusedField = .weight
                                }
                            }
                        }
                        .onChange(of: weightString) { newValue in
                            // Validate input without immediately updating the binding
                            let filteredValue = newValue.filter { $0.isNumber || $0 == "." }
                            
                            // Only proceed if the value changed meaningfully
                            guard filteredValue == newValue else {
                                // Use DispatchQueue to prevent immediate state update that dismisses keyboard
                                DispatchQueue.main.async {
                                    weightString = filteredValue
                                }
                                return
                            }
                            
                            // Update Core Data model
                            if filteredValue.isEmpty {
                                // Clear weight when input is empty
                                if set.isBodyweight {
                                    set.extraWeight = 0
                                } else {
                                    set.weight = 0
                                }
                                debouncedSave()
                                return
                            }
                            
                            // Update Core Data model with validated value
                            let displayValue = min(Double(filteredValue) ?? 0, 999.9)
                            let kgValue = Units.displayToKg(displayValue, unit: weightUnit)
                            if set.isBodyweight {
                                set.extraWeight = kgValue
                            } else {
                                set.weight = kgValue
                            }
                            
                            // Only check completion if we have meaningful weight (> 0)
                            if kgValue > 0 {
                                updateCompletionStatus()
                            }
                            debouncedSave()
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
                        .focused($focusedField, equals: .reps)
                        .onTapGesture {
                            focusedField = .reps
                            editingFocus = .reps(setIdString)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                withAnimation(.none) {
                                    focusedField = .reps
                                }
                            }
                        }
                        .onChange(of: repsString) { newValue in
                            // Validate input without immediately updating the binding
                            let filteredValue = newValue.filter { $0.isNumber }
                            
                            // Only proceed if the value changed meaningfully
                            guard filteredValue == newValue else {
                                // Use DispatchQueue to prevent immediate state update that dismisses keyboard
                                DispatchQueue.main.async {
                                    repsString = filteredValue
                                }
                                return
                            }
                            
                            // Update Core Data model
                            if filteredValue.isEmpty {
                                // Clear reps when input is empty
                                set.reps = 0
                                debouncedSave()
                                return
                            }
                            
                            // Update Core Data model with validated value
                            let repsValue = min(Int(filteredValue) ?? 0, 999)
                            set.reps = Int16(repsValue)
                            
                            // Only check completion if we have meaningful reps (> 0)
                            if repsValue > 0 {
                                updateCompletionStatus()
                            }
                            debouncedSave()
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
        .onChange(of: editingFocus) { newValue in
            guard let newValue = newValue else { return }
            switch newValue {
            case .weight(let id):
                if id == setIdString {
                    withAnimation(.none) {
                        focusedField = .weight
                    }
                }
            case .reps(let id):
                if id == setIdString {
                    withAnimation(.none) {
                        focusedField = .reps
                    }
                }
            }
        }
        .onAppear {
            updateWeightDisplay()
            repsString = set.reps > 0 ? String(set.reps) : ""
        }
        .alert("Save Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func updateWeightDisplay() {
        if set.isBodyweight {
            let disp = Units.kgToDisplay(set.extraWeight, unit: weightUnit)
            weightString = disp > 0 ? String(disp) : ""
        } else {
            let disp = Units.kgToDisplay(set.weight, unit: weightUnit)
            weightString = disp > 0 ? String(disp) : ""
        }
    }
    
    private func updateCompletionStatus() {
        let wasCompleted = set.isCompleted
        let isNowCompleted = setIsCompleted
        
        // Only update if status actually changed to avoid unnecessary Core Data writes
        if wasCompleted != isNowCompleted {
            set.isCompleted = isNowCompleted
            
            // Auto-start rest timer when set becomes completed
            if !wasCompleted && isNowCompleted {
                #if DEBUG
                print("🎯 Set completed! Triggering rest timer")
                #endif
                onSetCompleted?()
            }
        }
    }
    
    private func debouncedSave() {
        // Cancel previous save work item
        saveWorkItem?.cancel()
        
        // Create new work item with 1 second delay to be more aggressive
        saveWorkItem = DispatchWorkItem {
            saveContext()
        }
        
        // Schedule the work item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: saveWorkItem!)
    }
    
    private func saveContext() {
        do {
            try set.managedObjectContext?.save()
        } catch {
            #if DEBUG
            print("Error saving set: \(error)")
            #endif
            
            // Show user-friendly error message
            errorMessage = "Failed to save your set data. Please try again."
            showingErrorAlert = true
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