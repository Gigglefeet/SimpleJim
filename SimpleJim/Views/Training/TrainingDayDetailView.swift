import SwiftUI
import CoreData

struct TrainingDayDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var trainingDay: TrainingDay
    
    @State private var showingAddExercise = false
    @State private var showingSleepInput = false
    @State private var showingProteinInput = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    var exercises: [Exercise] {
        guard let exerciseSet = trainingDay.exercises?.allObjects as? [Exercise] else { return [] }
        return exerciseSet.sorted { $0.order < $1.order }
    }
    
    var body: some View {
        List {
            // Training day summary
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(dateFormatter.string(from: trainingDay.date))
                        .font(.title2)
                        .bold()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Weight")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(trainingDay.totalWeightLifted))kg")
                                .font(.title3)
                                .bold()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Total Sets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(trainingDay.totalSets)")
                                .font(.title3)
                                .bold()
                        }
                    }
                    
                    // Recovery info
                    if trainingDay.recoveryDays > 0 {
                        Text("\(trainingDay.recoveryDays) days since last training")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Exercises
            Section("Exercises") {
                ForEach(exercises) { exercise in
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        ExerciseRowView(exercise: exercise)
                    }
                }
                .onDelete(perform: deleteExercises)
                
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
            
            // Daily metrics
            Section("Daily Metrics") {
                Button(action: {
                    showingSleepInput = true
                }) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.blue)
                        Text("Sleep")
                        Spacer()
                        Text(trainingDay.sleepHours > 0 ? "\(trainingDay.sleepHours, specifier: "%.1f")h" : "Not logged")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingProteinInput = true
                }) {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text("Protein")
                        Spacer()
                        Text(trainingDay.proteinGrams > 0 ? "\(Int(trainingDay.proteinGrams))g" : "Not logged")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Training Day")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(trainingDay: trainingDay)
        }
        .sheet(isPresented: $showingSleepInput) {
            SleepInputView(trainingDay: trainingDay)
        }
        .sheet(isPresented: $showingProteinInput) {
            ProteinInputView(trainingDay: trainingDay)
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            offsets.map { exercises[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                
                Spacer()
                
                Text(exercise.muscleGroup)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if !exercise.sets.isEmpty {
                HStack {
                    Text("\(exercise.sets.count) sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(exercise.totalWeight))kg total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if exercise.maxWeight > 0 {
                        Text("• \(Int(exercise.maxWeight))kg max")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No sets logged")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct TrainingDayDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingDayDetailView(trainingDay: PersistenceController.preview.container.viewContext.registeredObjects.first(where: { $0 is TrainingDay }) as! TrainingDay)
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 