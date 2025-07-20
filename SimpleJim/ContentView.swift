import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var hasPerformedStartupCleanup = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProgramListView()
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("Programs")
                }
                .tag(0)
            
            ProgressView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Progress")
                }
                .tag(1)
            
            HealthView()
                .tabItem {
                    Image(systemName: "heart.text.square.fill")
                    Text("Health")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(.orange)
        .onAppear {
            if !hasPerformedStartupCleanup {
                cleanupOrphanedSessions()
                hasPerformedStartupCleanup = true
            }
        }
    }
    
    /// Recovers orphaned workout sessions by setting their end times
    private func cleanupOrphanedSessions() {
        let request: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "startTime != nil AND endTime == nil")
        
        do {
            let orphanedSessions = try viewContext.fetch(request)
            
            if !orphanedSessions.isEmpty {
                #if DEBUG
                print("🔧 Found \(orphanedSessions.count) orphaned workout session(s), cleaning up...")
                #endif
                
                for session in orphanedSessions {
                    // Set end time to a reasonable estimate (3 hours after start time or last set time)
                    if let startTime = session.startTime {
                        let estimatedEndTime = Calendar.current.date(byAdding: .hour, value: 3, to: startTime) ?? startTime
                        session.setValue(estimatedEndTime, forKey: "endTime")
                        
                        #if DEBUG
                        print("🔧 Recovered session from \(startTime) to \(estimatedEndTime)")
                        #endif
                    }
                }
                
                try viewContext.save()
                
                #if DEBUG
                print("✅ Successfully recovered \(orphanedSessions.count) orphaned session(s)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to cleanup orphaned sessions: \(error)")
            #endif
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 