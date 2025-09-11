import SwiftUI
import CoreData

struct QuickAddExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let dayTemplate: TrainingDayTemplate
    let trainingSession: TrainingSession
    let onExerciseAdded: (ExerciseTemplate) -> Void
    
    @State private var exerciseName = ""
    @State private var selectedMuscleGroup = "Chest"
    @State private var targetSets = 3
    @State private var notes = ""
    @State private var isCreating = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private let muscleGroups = [
        "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Legs", 
        "Quads", "Hamstrings", "Glutes", "Calves", "Core", "Cardio"
    ]
    
    private struct ExerciseSuggestion {
        let name: String
        let muscleGroup: String
        let sets: Int
    }
    
    private let quickExerciseSuggestions = [
        ExerciseSuggestion(name: "Plank", muscleGroup: "Core", sets: 3),
        ExerciseSuggestion(name: "Abs Crunches", muscleGroup: "Core", sets: 3),
        ExerciseSuggestion(name: "Russian Twists", muscleGroup: "Core", sets: 3),
        ExerciseSuggestion(name: "Mountain Climbers", muscleGroup: "Cardio", sets: 3),
        ExerciseSuggestion(name: "Face Pulls", muscleGroup: "Shoulders", sets: 3),
        ExerciseSuggestion(name: "Calf Raises", muscleGroup: "Calves", sets: 4),
        ExerciseSuggestion(name: "Bicep Curls", muscleGroup: "Biceps", sets: 3),
        ExerciseSuggestion(name: "Tricep Dips", muscleGroup: "Triceps", sets: 3)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with workout context
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        Text("Quick Add Exercise")
                            .font(.headline)
                            .bold()
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Adding to: \(dayTemplate.name ?? "Training Day")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // Show encouragement for end-of-workout additions
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        
                        Text("Perfect time for abs, cardio, or accessory work!")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .italic()
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Quick form
                Form {
                    Section {
                        TextField("Exercise name (e.g., Cable Flyes)", text: $exerciseName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } header: {
                        Text("Exercise Name")
                    } footer: {
                        Text("Keep it simple - you can always edit details later")
                    }
                    
                    Section {
                        Picker("Muscle Group", selection: $selectedMuscleGroup) {
                            ForEach(muscleGroups, id: \.self) { group in
                                Text(group).tag(group)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        HStack {
                            Text("Target Sets")
                            
                            Spacer()
                            
                            Stepper("\(targetSets)", value: $targetSets, in: 1...8)
                                .labelsHidden()
                        }
                    } header: {
                        Text("Quick Setup")
                    }
                    
                    Section {
                        TextField("Quick notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(2)
                    } header: {
                        Text("Notes")
                    } footer: {
                        Text("💡 Tip: Focus on your workout - detailed planning can happen later!")
                    }
                    
                    // Quick suggestions for common end-of-workout exercises
                    Section {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(quickExerciseSuggestions, id: \.name) { suggestion in
                                Button(action: {
                                    exerciseName = suggestion.name
                                    selectedMuscleGroup = suggestion.muscleGroup
                                    targetSets = suggestion.sets
                                }) {
                                    VStack(spacing: 4) {
                                        Text(suggestion.name)
                                            .font(.caption)
                                            .bold()
                                            .multilineTextAlignment(.center)
                                        
                                        Text("\(suggestion.sets) sets • \(suggestion.muscleGroup)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                    } header: {
                        Text("Quick Suggestions")
                    } footer: {
                        Text("Tap any suggestion to auto-fill, or enter your own exercise above")
                    }
                    
                    // Action buttons
                    Section {
                        Button(action: {
                            addExerciseQuickly()
                        }) {
                            HStack {
                                if isCreating {
                                    TrainingProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                
                                Text(isCreating ? "Adding..." : "Add & Start Exercise")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                        }
                        .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                        .listRowBackground(
                            exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating 
                            ? Color.gray.opacity(0.3) 
                            : Color.blue
                        )
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .overlay(alignment: .topTrailing) {
            // Close button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .padding()
        }
    }
    
    private func addExerciseQuickly() {
        guard !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        
        // Create the exercise template
        let newExerciseTemplate = ExerciseTemplate(context: viewContext)
        newExerciseTemplate.name = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        newExerciseTemplate.muscleGroup = selectedMuscleGroup
        newExerciseTemplate.targetSets = Int16(targetSets)
        newExerciseTemplate.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        newExerciseTemplate.order = Int16(dayTemplate.sortedExerciseTemplates.count)
        newExerciseTemplate.supersetGroup = 0 // Default to standalone exercise
        newExerciseTemplate.dayTemplate = dayTemplate
        
        do {
            try viewContext.save()
            
            #if DEBUG
            print("✅ Created new exercise template: \(newExerciseTemplate.name ?? "Unknown")")
            #endif
            
            // Call the completion handler
            onExerciseAdded(newExerciseTemplate)
            
            // Dismiss the modal
            dismiss()
            
        } catch {
            #if DEBUG
            print("❌ Failed to create exercise template: \(error.localizedDescription)")
            #endif
            
            isCreating = false
            errorMessage = "Failed to add exercise. Please try again."
            showingErrorAlert = true
        }
    }
}

struct QuickAddExerciseView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let dayTemplate = TrainingDayTemplate(context: context)
        dayTemplate.name = "Push Day"
        
        let session = TrainingSession(context: context)
        session.date = Date()
        
        return QuickAddExerciseView(
            dayTemplate: dayTemplate,
            trainingSession: session,
            onExerciseAdded: { _ in }
        )
        .environment(\.managedObjectContext, context)
    }
}
