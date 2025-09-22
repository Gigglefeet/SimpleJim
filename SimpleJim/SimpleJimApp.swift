import SwiftUI
import CoreData
import UserNotifications

extension Notification.Name {
    static let resumeWorkout = Notification.Name("resumeWorkout")
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if let type = info["type"] as? String, type == "rest_timer_complete" {
            if let sessionID = info["sessionID"] as? String {
                await MainActor.run {
                    NotificationCenter.default.post(name: .resumeWorkout, object: sessionID)
                }
            }
        }
    }
}

@main
struct SimpleJimApp: App {
    let persistenceController = PersistenceController.shared
    private let notificationDelegate = NotificationDelegate()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                }
        }
    }
} 