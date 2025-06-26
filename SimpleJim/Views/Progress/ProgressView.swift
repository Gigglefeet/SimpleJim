import SwiftUI
import CoreData

struct ProgressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
        animation: .default)
    private var trainingSessions: FetchedResults<TrainingSession>
    
    var body: some View {
        NavigationView {
            List {
                Section("Progress Overview") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Total Training Sessions")
                            .font(.headline)
                        Text("\(trainingSessions.count)")
                            .font(.title)
                            .bold()
                            .foregroundColor(.orange)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Weight Lifted")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(totalWeightLifted))kg")
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Average Sleep")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(averageSleep, specifier: "%.1f")h")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Charts & Analytics") {
                    Label("Weight Progress", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.gray)
                    
                    Label("Sleep vs Performance", systemImage: "moon.stars")
                        .foregroundColor(.gray)
                    
                    Label("Protein Tracking", systemImage: "leaf.circle")
                        .foregroundColor(.gray)
                    
                    Label("Recovery Analysis", systemImage: "heart.circle")
                        .foregroundColor(.gray)
                    
                    Text("Charts coming soon...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .navigationTitle("Progress")
        }
    }
    
    private var totalWeightLifted: Double {
        trainingSessions.reduce(0) { total, session in
            total + session.totalWeightLifted
        }
    }
    
    private var averageSleep: Double {
        let sleepSessions = trainingSessions.filter { $0.sleepHours > 0 }
        guard !sleepSessions.isEmpty else { return 0 }
        return sleepSessions.reduce(0) { total, session in
            total + session.sleepHours
        } / Double(sleepSessions.count)
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 