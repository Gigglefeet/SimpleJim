import SwiftUI
import CoreData
import os.log

struct DayTemplateDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var dayTemplate: TrainingDayTemplate
    
    @State private var showingAddExercise = false
    @State private var showingWorkoutSession = false
    @State private var currentTrainingSession: TrainingSession?
    @State private var draggedExercise: ExerciseTemplate?
    @State private var dragTargetExercise: ExerciseTemplate?
    @State private var showingSupersetHint = false
    
    var body: some View {
        List {
            // Day template info
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(dayTemplate.name ?? "Unnamed Day")
                        .font(.title2)
                        .bold()
                    
                    if let notes = dayTemplate.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Day \(dayTemplate.order + 1)", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Label("\(dayTemplate.totalExercises) exercises", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            if dayTemplate.sortedExerciseTemplates.isEmpty {
                // Empty state
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 40))
                            .foregroundColor(.orange.opacity(0.6))
                        
                        Text("No exercises yet")
                            .font(.headline)
                        
                        Text("Add your first exercise to this training day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showingAddExercise = true
                        }) {
                            Text("Add Exercise")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
            } else {
                // Exercise groups (standalone and supersets)
                Section("Exercises") {
                    ForEach(dayTemplate.exerciseGroups) { group in
                        if group.isSuperset {
                            SupersetGroupView(
                                group: group,
                                draggedExercise: $draggedExercise,
                                dragTargetExercise: $dragTargetExercise,
                                onBreakSuperset: { exercises in
                                    breakSuperset(exercises: exercises)
                                }
                            )
                        } else {
                            ForEach(group.exercises, id: \.objectID) { exercise in
                                ExerciseTemplateRowView(
                                    exerciseTemplate: exercise,
                                    draggedExercise: $draggedExercise,
                                    dragTargetExercise: $dragTargetExercise,
                                    onCreateSuperset: { exercise1, exercise2 in
                                        createSuperset(from: [exercise1, exercise2])
                                    }
                                )
                            }
                        }
                    }
                    
                    // Add exercise button
                    Button(action: {
                        showingAddExercise = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.orange)
                            Text("Add Exercise")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Superset help section
                if dayTemplate.totalExercises >= 2 && !dayTemplate.exerciseGroups.contains(where: { $0.isSuperset }) {
                    Section {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Create Supersets")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Tap an exercise to select it, then tap another to create a superset")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Quick actions
                Section("Actions") {
                    Button(action: {
                        startWorkout()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start Workout")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Begin a training session from this template")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationTitle("Training Day")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddExercise) {
            CreateExerciseTemplateView(dayTemplate: dayTemplate)
        }
        .fullScreenCover(isPresented: $showingWorkoutSession) {
            if let session = currentTrainingSession {
                WorkoutSessionView(dayTemplate: dayTemplate, trainingSession: session)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSuperset(from exercises: [ExerciseTemplate]) {
        #if DEBUG
        print("🎯 Creating superset from: \(exercises.map { $0.name ?? "Unknown" })")
        #endif
        
        withAnimation(.spring()) {
            dayTemplate.createSuperset(from: exercises, in: viewContext)
            
            // Force UI refresh by updating the managed object context
            viewContext.refresh(dayTemplate, mergeChanges: true)
            
            #if DEBUG
            print("✅ Superset created! Groups now: \(dayTemplate.exerciseGroups.count)")
            for group in dayTemplate.exerciseGroups {
                print("   - \(group.isSuperset ? "Superset" : "Standalone"): \(group.exercises.map { $0.name ?? "Unknown" })")
            }
            #endif
        }
    }
    
    private func breakSuperset(exercises: [ExerciseTemplate]) {
        #if DEBUG
        print("💥 Breaking superset: \(exercises.map { $0.name ?? "Unknown" })")
        #endif
        
        withAnimation(.spring()) {
            dayTemplate.removeFromSuperset(exercises: exercises, in: viewContext)
            
            // Force UI refresh
            viewContext.refresh(dayTemplate, mergeChanges: true)
            
            #if DEBUG
            print("✅ Superset broken! Groups now: \(dayTemplate.exerciseGroups.count)")
            #endif
        }
    }
    
    private func startWorkout() {
        // Create a new training session
        let newSession = TrainingSession(context: viewContext)
        let now = Date()
        newSession.date = now
        newSession.setValue(now, forKey: "startTime")
        newSession.setValue(nil, forKey: "endTime")
        newSession.template = dayTemplate
        newSession.notes = nil
        newSession.sleepHours = 0
        newSession.proteinGrams = 0
        newSession.userBodyweight = getUserBodyweight()
        
        do {
            try viewContext.save()
            currentTrainingSession = newSession
            showingWorkoutSession = true
        } catch {
            os_log("Failed to start workout session: %@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    private func getUserBodyweight() -> Double {
        let fetchRequest: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userBodyweight > 0")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        if let lastSession = try? viewContext.fetch(fetchRequest).first {
            return lastSession.userBodyweight
        }
        
        return UserDefaults.standard.double(forKey: "defaultBodyweight") != 0 ? UserDefaults.standard.double(forKey: "defaultBodyweight") : 70.0
    }
}

// MARK: - Superset Group View

struct SupersetGroupView: View {
    let group: ExerciseGroup
    @Binding var draggedExercise: ExerciseTemplate?
    @Binding var dragTargetExercise: ExerciseTemplate?
    let onBreakSuperset: ([ExerciseTemplate]) -> Void
    
    private var supersetColor: Color {
        let colors: [Color] = [.orange, .blue, .green, .purple, .red, .pink]
        let index = Int(group.supersetNumber ?? 1) - 1
        return colors[index % colors.count]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Superset header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Text(group.displayTitle)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(supersetColor)
                .cornerRadius(12)
                
                Spacer()
                
                Button(action: {
                    onBreakSuperset(group.exercises)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Superset exercises
            VStack(spacing: 4) {
                ForEach(Array(group.exercises.enumerated()), id: \.element.objectID) { index, exercise in
                    SupersetExerciseRowView(
                        exercise: exercise,
                        label: group.supersetLabels[index],
                        color: supersetColor,
                        isLast: index == group.exercises.count - 1
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(supersetColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(supersetColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Superset Exercise Row

struct SupersetExerciseRowView: View {
    let exercise: ExerciseTemplate
    let label: String
    let color: Color
    let isLast: Bool
    
    var body: some View {
        HStack {
            // Superset label
            Text(label)
                .font(.caption)
                .bold()
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.name ?? "Unnamed Exercise")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(exercise.muscleGroup ?? "")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(6)
                }
                
                if let notes = exercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label("\(exercise.targetSets) sets", systemImage: "number.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            if !isLast {
                VStack {
                    Spacer()
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundColor(color)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Enhanced Exercise Template Row

struct ExerciseTemplateRowView: View {
    let exerciseTemplate: ExerciseTemplate
    @Binding var draggedExercise: ExerciseTemplate?
    @Binding var dragTargetExercise: ExerciseTemplate?
    let onCreateSuperset: (ExerciseTemplate, ExerciseTemplate) -> Void
    
    @State private var isDragTarget = false
    @State private var showingDropZone = false
    @State private var isSelected = false
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.orange.opacity(0.3)
        } else if isDragTarget {
            return Color.orange.opacity(0.2)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.orange
        } else if isDragTarget {
            return Color.orange
        } else {
            return Color.clear
        }
    }
    
    private var dragScale: CGFloat {
        isSelected ? 1.02 : 1.0
    }
    
    private var dragOpacity: Double {
        isSelected ? 0.9 : 1.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exerciseTemplate.name ?? "Unnamed Exercise")
                    .font(.headline)
                
                Spacer()
                
                Text(exerciseTemplate.muscleGroup ?? "")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if let notes = exerciseTemplate.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(exerciseTemplate.targetSets) sets", systemImage: "number.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Exercise \(exerciseTemplate.order + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Show superset hint when exercise is selected
                if isSelected {
                    Text("Tap another exercise to create superset")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .italic()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 2)
        )
        .scaleEffect(dragScale)
        .opacity(dragOpacity)
        .animation(.spring(response: 0.3), value: isSelected)
        .animation(.spring(response: 0.3), value: isDragTarget)
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            handleLongPress()
        }
        .onChange(of: draggedExercise) { newValue in
            if newValue == nil {
                isSelected = false
                isDragTarget = false
            } else if newValue == exerciseTemplate {
                isSelected = true
                isDragTarget = false
            } else if !exerciseTemplate.isInSuperset && !newValue!.isInSuperset {
                isDragTarget = true
                isSelected = false
            } else {
                isDragTarget = false
                isSelected = false
            }
        }
    }
    
    private func handleTap() {
        #if DEBUG
        print("👆 Tapped: \(exerciseTemplate.name ?? "Unknown")")
        #endif
        
        if let draggedExercise = draggedExercise,
           draggedExercise != exerciseTemplate,
           !draggedExercise.isInSuperset,
           !exerciseTemplate.isInSuperset {
            
            #if DEBUG
            print("✅ Creating superset between: \(draggedExercise.name ?? "Unknown") and \(exerciseTemplate.name ?? "Unknown")")
            #endif
            
            onCreateSuperset(draggedExercise, exerciseTemplate)
            self.draggedExercise = nil
        } else if draggedExercise == exerciseTemplate {
            // Deselect if tapping the same exercise
            #if DEBUG
            print("🔄 Deselecting: \(exerciseTemplate.name ?? "Unknown")")
            #endif
            self.draggedExercise = nil
        } else if !exerciseTemplate.isInSuperset {
            // Select this exercise for superset creation
            #if DEBUG
            print("🎯 Selected for superset: \(exerciseTemplate.name ?? "Unknown")")
            #endif
            self.draggedExercise = exerciseTemplate
        }
    }
    
    private func handleLongPress() {
        guard !exerciseTemplate.isInSuperset else { return }
        
        #if DEBUG
        print("👆🔒 Long pressed: \(exerciseTemplate.name ?? "Unknown")")
        #endif
        
        self.draggedExercise = exerciseTemplate
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Drag & Drop Support

// Simple drag and drop using NSItemProvider and object ID strings

struct DayTemplateDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DayTemplateDetailView(dayTemplate: {
                let context = PersistenceController.preview.container.viewContext
                let dayTemplate = TrainingDayTemplate(context: context)
                dayTemplate.name = "Push Day"
                dayTemplate.notes = "Chest, shoulders, triceps"
                dayTemplate.order = 0
                return dayTemplate
            }())
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 