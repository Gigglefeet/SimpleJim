import SwiftUI
import CoreData

struct ExerciseDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var exercise: Exercise
    
    @State private var newWeight: String = ""
    @State private var newReps: String = ""
    @State private var isAddingSet = false
    
    var body: some View {
        List {
            // Exercise summary
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(exercise.name)
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        Text(exercise.muscleGroup)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    if let notes = exercise.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Volume")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(exercise.totalWeight))kg")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center) {
                            Text("Max Weight")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(exercise.maxWeight))kg")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Total Reps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(exercise.totalReps)")
                                .font(.headline)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Sets
            Section("Sets") {
                ForEach(exercise.sets) { set in
                    SetRowView(set: set)
                }
                .onDelete(perform: deleteSets)
                
                // Add new set
                if isAddingSet {
                    HStack {
                        TextField("Weight", text: $newWeight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("kg ×")
                            .foregroundColor(.secondary)
                        
                        TextField("Reps", text: $newReps)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add") {
                            addSet()
                        }
                        .disabled(newWeight.isEmpty || newReps.isEmpty)
                        
                        Button("Cancel") {
                            cancelAddSet()
                        }
                        .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: {
                        isAddingSet = true
                        // Pre-fill with last set's weight if available
                        if let lastSet = exercise.sets.last {
                            newWeight = String(format: "%.1f", lastSet.weight)
                            newReps = String(lastSet.reps)
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.orange)
                            Text("Add Set")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addSet() {
        guard let weight = Double(newWeight),
              let reps = Int16(newReps) else { return }
        
        withAnimation {
            let newSet = ExerciseSet(context: viewContext)
            newSet.weight = weight
            newSet.reps = reps
            newSet.order = Int16(exercise.sets.count)
            newSet.isCompleted = true
            newSet.exercise = exercise
            
            do {
                try viewContext.save()
                cancelAddSet()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func cancelAddSet() {
        isAddingSet = false
        newWeight = ""
        newReps = ""
    }
    
    private func deleteSets(offsets: IndexSet) {
        withAnimation {
            offsets.map { exercise.sets[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct SetRowView: View {
    let set: ExerciseSet
    
    var body: some View {
        HStack {
            Circle()
                .fill(set.isCompleted ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)
            
            Text("Set \(set.order + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(set.weight, specifier: "%.1f")kg")
                .font(.headline)
            
            Text("×")
                .foregroundColor(.secondary)
            
            Text("\(set.reps)")
                .font(.headline)
            
            Text("=")
                .foregroundColor(.secondary)
                .font(.caption)
            
            Text("\(Int(set.volume))kg")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct ExerciseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExerciseDetailView(exercise: {
                let context = PersistenceController.preview.container.viewContext
                return context.registeredObjects.first(where: { $0 is Exercise }) as! Exercise
            }())
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 