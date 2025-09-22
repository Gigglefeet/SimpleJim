import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var hasPerformedStartupCleanup = false
    @State private var resumeSessionObjectIDURL: URL? = nil
    @State private var showResumeSheet = false
    @State private var resumeObserver: NSObjectProtocol? = nil
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProgramListView()
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("Programs")
                }
                .tag(0)
            
            TrainingProgressView()
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
            // Install observer once to avoid duplicate sheet presentations
            if resumeObserver == nil {
                resumeObserver = NotificationCenter.default.addObserver(forName: .resumeWorkout, object: nil, queue: .main) { notif in
                    guard let sessionID = notif.object as? String, let url = URL(string: sessionID) else { return }
                    // Avoid duplicate presentations if sheet is already visible or same URL is pending
                    if showResumeSheet, resumeSessionObjectIDURL == url { return }
                    resumeSessionObjectIDURL = url
                    showResumeSheet = true
                }
            }
        }
        .onDisappear {
            if let token = resumeObserver {
                NotificationCenter.default.removeObserver(token)
                resumeObserver = nil
            }
        }
        .sheet(isPresented: $showResumeSheet) {
            if let url = resumeSessionObjectIDURL,
               let psc = viewContext.persistentStoreCoordinator,
               let objectID = psc.managedObjectID(forURIRepresentation: url),
               let resolved = try? viewContext.existingObject(with: objectID),
               let session = resolved as? TrainingSession,
               let template = session.template {
                WorkoutSessionView(dayTemplate: template, trainingSession: session)
                    .environment(\.managedObjectContext, viewContext)
            } else {
                Text("Could not restore workout session.")
            }
        }
    }
    
    /// Recovers clearly orphaned workout sessions by setting their end times.
    /// Avoids touching very recent in-progress sessions to prevent nuking an active workout on app wake.
    private func cleanupOrphanedSessions() {
        let request: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "startTime != nil AND endTime == nil")
        
        do {
            let orphanedSessions = try viewContext.fetch(request)
            
            if !orphanedSessions.isEmpty {
                #if DEBUG
                print("🔧 Found \(orphanedSessions.count) orphaned workout session(s), cleaning up...")
                #endif
                
                let now = Date()
                // Only close sessions that started sufficiently long ago (e.g., > 6 hours)
                // so we don't prematurely end an active session after sleep/background.
                for session in orphanedSessions {
                    guard let startTime = session.startTime else { continue }
                    let hoursSinceStart = now.timeIntervalSince(startTime) / 3600.0
                    guard hoursSinceStart > 6 else { continue }
                    // Set end time to a reasonable estimate (3 hours after start time or last set time)
                    let estimatedEndTime = Calendar.current.date(byAdding: .hour, value: 3, to: startTime) ?? startTime
                    session.setValue(estimatedEndTime, forKey: "endTime")
                    
                    #if DEBUG
                    print("🔧 Recovered stale session from \(startTime) to \(estimatedEndTime)")
                    #endif
                }
                
                try viewContext.save()
                
                #if DEBUG
                print("✅ Orphaned session cleanup completed")
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