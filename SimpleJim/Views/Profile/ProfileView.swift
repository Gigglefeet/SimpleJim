import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Goals") {
                    Label("Set Training Goals", systemImage: "target")
                        .foregroundColor(.gray)
                    
                    Label("Sleep Target", systemImage: "moon")
                        .foregroundColor(.gray)
                    
                    Label("Protein Goal", systemImage: "leaf")
                        .foregroundColor(.gray)
                }
                
                Section("Data") {
                    Label("Export Training Data", systemImage: "square.and.arrow.up")
                        .foregroundColor(.gray)
                    
                    Label("Import Previous Data", systemImage: "square.and.arrow.down")
                        .foregroundColor(.gray)
                }
                
                Section("Settings") {
                    Label("Units & Preferences", systemImage: "gearshape")
                        .foregroundColor(.gray)
                    
                    Label("Notifications", systemImage: "bell")
                        .foregroundColor(.gray)
                }
                
                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SimpleJim")
                            .font(.headline)
                        
                        Text("Simple, effective gym tracking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
} 