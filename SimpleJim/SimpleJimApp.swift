import SwiftUI
import CoreData
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if let type = info["type"] as? String, type == "rest_timer_complete" {
            // In the future, we could route to the active workout using sessionID
            // For now, no-op; the app will restore timers on foreground
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