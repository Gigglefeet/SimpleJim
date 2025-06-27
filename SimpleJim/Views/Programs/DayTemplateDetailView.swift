import SwiftUI
import CoreData

struct DayTemplateDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var dayTemplate: TrainingDayTemplate
    
    @State private var showingAddExercise = false
    @State private var showingWorkoutSession = false
    @State private var currentTrainingSession: TrainingSession?
    
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
                // Exercise templates
                Section("Exercises") {
                    ForEach(dayTemplate.sortedExerciseTemplates) { exerciseTemplate in
                        ExerciseTemplateRowView(exerciseTemplate: exerciseTemplate)
                    }
                    
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
        newSession.userBodyweight = getUserBodyweight() // Set user's bodyweight
        
        do {
            try viewContext.save()
            currentTrainingSession = newSession
            showingWorkoutSession = true
            print("✅ Started workout session for \(dayTemplate.name ?? "Unknown")")
        } catch {
            print("❌ Error starting workout: \(error)")
        }
    }
    
    private func getUserBodyweight() -> Double {
        // Get the most recent bodyweight from previous sessions
        let fetchRequest: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userBodyweight > 0")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        if let lastSession = try? viewContext.fetch(fetchRequest).first {
            return lastSession.userBodyweight
        }
        
        // Default to 70kg if no previous sessions
        return 70.0
    }
}

struct ExerciseTemplateRowView: View {
    let exerciseTemplate: ExerciseTemplate
    
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
            }
        }
        .padding(.vertical, 2)
    }
}

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