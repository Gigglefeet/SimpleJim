import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 