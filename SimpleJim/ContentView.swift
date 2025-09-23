import SwiftUI
import CoreData

@MainActor
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var hasPerformedStartupCleanup = false
    @State private var resumeSessionObjectIDURL: URL? = nil
    @State private var activeSession: TrainingSession? = nil
    @State private var resumeObserver: NSObjectProtocol? = nil
    @State private var pendingResumeURL: URL? = nil
    @State private var finishObserver: NSObjectProtocol? = nil
    
    var body: some View {
        Group {
            if let session = activeSession, let template = session.template {
                WorkoutSessionView(dayTemplate: template, trainingSession: session)
                    .environment(\.managedObjectContext, viewContext)
            } else {
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
            }
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
                    // Avoid duplicate switching if already in session for this URL
                    if let current = resumeSessionObjectIDURL, current == url, activeSession != nil { return }
                    pendingResumeURL = url
                    if scenePhase == .active {
                        resumeSessionObjectIDURL = url
                        activateSessionFromURL(url)
                        pendingResumeURL = nil
                    }
                }
            }
            if finishObserver == nil {
                finishObserver = NotificationCenter.default.addObserver(forName: .workoutDidFinish, object: nil, queue: .main) { _ in
                    activeSession = nil
                    resumeSessionObjectIDURL = nil
                }
            }
        }
        .onDisappear {
            if let token = resumeObserver {
                NotificationCenter.default.removeObserver(token)
                resumeObserver = nil
            }
            if let token = finishObserver {
                NotificationCenter.default.removeObserver(token)
                finishObserver = nil
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, let url = pendingResumeURL {
                if resumeSessionObjectIDURL != url {
                    resumeSessionObjectIDURL = url
                }
                activateSessionFromURL(url)
                pendingResumeURL = nil
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

    private func fetchLatestInProgressSession() -> TrainingSession? {
        let request: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "startTime != nil AND endTime == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = 1
        do {
            return try viewContext.fetch(request).first
        } catch {
            #if DEBUG
            print("❌ Failed to fetch in-progress session: \(error)")
            #endif
            return nil
        }
    }

    private func activateSessionFromURL(_ url: URL) {
        guard let psc = viewContext.persistentStoreCoordinator,
              let objectID = psc.managedObjectID(forURIRepresentation: url) else {
            // Fallback if URL cannot be resolved
            if let fallback = fetchLatestInProgressSession() {
                activeSession = fallback
            }
            return
        }
        do {
            let resolved = try viewContext.existingObject(with: objectID)
            if let session = resolved as? TrainingSession {
                activeSession = session
            } else if let fallback = fetchLatestInProgressSession() {
                activeSession = fallback
            }
        } catch {
            #if DEBUG
            print("❌ Failed to resolve session from URL: \(error)")
            #endif
            if let fallback = fetchLatestInProgressSession() {
                activeSession = fallback
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 