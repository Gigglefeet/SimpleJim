import SwiftUI
import CoreData

struct TrainingDayListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TrainingDay.date, ascending: false)],
        animation: .default)
    private var trainingDays: FetchedResults<TrainingDay>
    
    @State private var showingNewTrainingDay = false
    
    var body: some View {
        NavigationView {
            List {
                // Quick start section
                Section {
                    Button(action: {
                        createTodaysTrainingDay()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start Today's Training")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Build your workout")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Recent training days
                Section("Recent Training Days") {
                    ForEach(trainingDays) { trainingDay in
                        NavigationLink(destination: TrainingDayDetailView(trainingDay: trainingDay)) {
                            TrainingDayRowView(trainingDay: trainingDay)
                        }
                    }
                    .onDelete(perform: deleteTrainingDays)
                }
            }
            .navigationTitle("SimpleJim")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func createTodaysTrainingDay() {
        withAnimation {
            let newTrainingDay = TrainingDay(context: viewContext)
            newTrainingDay.date = Date()
            newTrainingDay.sleepHours = 0
            newTrainingDay.proteinGrams = 0
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteTrainingDays(offsets: IndexSet) {
        withAnimation {
            offsets.map { trainingDays[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct TrainingDayRowView: View {
    let trainingDay: TrainingDay
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dateFormatter.string(from: trainingDay.date))
                    .font(.headline)
                
                Spacer()
                
                if trainingDay.recoveryDays > 0 {
                    Text("\(trainingDay.recoveryDays)d rest")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            HStack {
                Label("\(trainingDay.totalSets) sets", systemImage: "repeat")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("\(Int(trainingDay.totalWeightLifted))kg total", systemImage: "scalemass")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if trainingDay.sleepHours > 0 || trainingDay.proteinGrams > 0 {
                HStack {
                    if trainingDay.sleepHours > 0 {
                        Label("\(trainingDay.sleepHours, specifier: "%.1f")h sleep", systemImage: "moon")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if trainingDay.proteinGrams > 0 {
                        Label("\(Int(trainingDay.proteinGrams))g protein", systemImage: "leaf")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct TrainingDayListView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingDayListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 