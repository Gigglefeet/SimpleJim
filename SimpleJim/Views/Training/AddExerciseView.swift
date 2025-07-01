import SwiftUI
import CoreData

struct AddExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let trainingDayTemplate: TrainingDayTemplate
    
    @State private var exerciseName = ""
    @State private var selectedMuscleGroup = "Chest"
    @State private var exerciseNotes = ""
    @State private var targetSets: Int = 3
    
    private let muscleGroups = [
        "Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Cardio", "Other"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Template Details") {
                    TextField("Exercise name", text: $exerciseName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Muscle Group", selection: $selectedMuscleGroup) {
                        ForEach(muscleGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    HStack {
                        Text("Target Sets")
                        Spacer()
                        Stepper("\(targetSets)", value: $targetSets, in: 1...10)
                    }
                    
                    TextField("Notes (optional)", text: $exerciseNotes, axis: .vertical)
                        .lineLimit(3)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section {
                    Button("Add Exercise Template") {
                        addExerciseTemplate()
                    }
                    .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Add Exercise Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addExerciseTemplate() {
        withAnimation {
            let newTemplate = ExerciseTemplate(context: viewContext)
            newTemplate.name = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            newTemplate.muscleGroup = selectedMuscleGroup
            newTemplate.notes = exerciseNotes.isEmpty ? nil : exerciseNotes
            newTemplate.targetSets = Int16(targetSets)
            newTemplate.order = Int16(trainingDayTemplate.sortedExerciseTemplates.count)
            newTemplate.dayTemplate = trainingDayTemplate
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                // Log error and continue - user will see the exercise wasn't added
                #if DEBUG
                print("Failed to save exercise template: \(error.localizedDescription)")
                #endif
                // TODO: Show error alert to user
            }
        }
    }
}

struct AddExerciseView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        // Create a sample training day template for preview
        let sampleTemplate = TrainingDayTemplate(context: context)
        sampleTemplate.name = "Push Day"
        sampleTemplate.order = 0
        
        return AddExerciseView(trainingDayTemplate: sampleTemplate)
            .environment(\.managedObjectContext, context)
    }
} 