import SwiftUI
import CoreData

struct CreateExerciseTemplateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let dayTemplate: TrainingDayTemplate
    
    @State private var exerciseName = ""
    @State private var muscleGroup = "Chest"
    @State private var targetSets = 3
    @State private var notes = ""
    @State private var isCreating = false
    
    let muscleGroups = [
        "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Legs", 
        "Quads", "Hamstrings", "Glutes", "Calves", "Core", "Cardio"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Exercise name (e.g., Bench Press)", text: $exerciseName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } header: {
                    Text("Exercise Details")
                } footer: {
                    Text("Enter the name of the exercise you want to add")
                }
                
                Section {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(muscleGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                } header: {
                    Text("Target Muscle")
                }
                
                Section {
                    Stepper(value: $targetSets, in: 1...10) {
                        HStack {
                            Text("Target Sets")
                            Spacer()
                            Text("\(targetSets)")
                                .foregroundColor(.orange)
                                .bold()
                        }
                    }
                } header: {
                    Text("Volume")
                } footer: {
                    Text("How many sets do you plan to do for this exercise?")
                }
                
                Section {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Add form cues, weight progression notes, or other reminders")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's next:")
                            .font(.headline)
                        
                        Label("Exercise will be added to \(dayTemplate.name ?? "this day")", systemImage: "checkmark.circle")
                        Label("You can reorder exercises later", systemImage: "arrow.up.arrow.down")
                        Label("Start training to log actual weights", systemImage: "dumbbell")
                    }
                    .foregroundColor(.secondary)
                    .font(.caption)
                } header: {
                    Text("After Creating")
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        createExerciseTemplate()
                    }
                    .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createExerciseTemplate() {
        guard !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        
        let newExerciseTemplate = ExerciseTemplate(context: viewContext)
        newExerciseTemplate.name = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        newExerciseTemplate.muscleGroup = muscleGroup
        newExerciseTemplate.targetSets = Int16(targetSets)
        newExerciseTemplate.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        newExerciseTemplate.order = Int16(dayTemplate.sortedExerciseTemplates.count)
        newExerciseTemplate.dayTemplate = dayTemplate
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            #if DEBUG
            print("Failed to create exercise template: \(error.localizedDescription)")
            #endif
            isCreating = false
            // TODO: Show error alert to user
        }
    }
}

struct CreateExerciseTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        CreateExerciseTemplateView(dayTemplate: {
            let context = PersistenceController.preview.container.viewContext
            let dayTemplate = TrainingDayTemplate(context: context)
            dayTemplate.name = "Push Day"
            return dayTemplate
        }())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 