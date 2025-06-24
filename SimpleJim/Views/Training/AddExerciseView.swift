import SwiftUI
import CoreData

struct AddExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let trainingDay: TrainingDay
    
    @State private var exerciseName = ""
    @State private var selectedMuscleGroup = "Chest"
    @State private var exerciseNotes = ""
    
    private let muscleGroups = [
        "Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Cardio", "Other"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise name", text: $exerciseName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Muscle Group", selection: $selectedMuscleGroup) {
                        ForEach(muscleGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextField("Notes (optional)", text: $exerciseNotes, axis: .vertical)
                        .lineLimit(3)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section {
                    Button("Add Exercise") {
                        addExercise()
                    }
                    .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Add Exercise")
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
    
    private func addExercise() {
        withAnimation {
            let newExercise = Exercise(context: viewContext)
            newExercise.name = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            newExercise.muscleGroup = selectedMuscleGroup
            newExercise.notes = exerciseNotes.isEmpty ? nil : exerciseNotes
            newExercise.order = Int16((trainingDay.exercises?.count ?? 0))
            newExercise.trainingDay = trainingDay
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("❌ Error saving exercise: \(nsError), \(nsError.userInfo)")
                // Don't crash in production
                #if DEBUG
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                #endif
            }
        }
    }
}

struct AddExerciseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExerciseView(trainingDay: PersistenceController.preview.container.viewContext.registeredObjects.first(where: { $0 is TrainingDay }) as! TrainingDay)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 