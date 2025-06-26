import SwiftUI
import CoreData

struct ProgramListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TrainingProgram.createdDate, ascending: false)],
        animation: .default)
    private var programs: FetchedResults<TrainingProgram>
    
    @State private var showingCreateProgram = false
    
    var body: some View {
        NavigationView {
            List {
                if programs.isEmpty {
                    // Empty state
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange.opacity(0.6))
                            
                            Text("Welcome to SimpleJim!")
                                .font(.title2)
                                .bold()
                            
                            Text("Create your first training program to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                showingCreateProgram = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create Program")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    // Programs list
                    Section("My Training Programs") {
                        ForEach(programs) { program in
                            NavigationLink(destination: ProgramDetailView(program: program)) {
                                ProgramRowView(program: program)
                            }
                        }
                        .onDelete(perform: deletePrograms)
                    }
                    
                    // Quick create section
                    Section {
                        Button(action: {
                            showingCreateProgram = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Create New Program")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Build a custom training routine")
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
            .navigationTitle("SimpleJim")
            .toolbar {
                if !programs.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingCreateProgram) {
                CreateProgramView()
            }
        }
    }
    
    private func deletePrograms(offsets: IndexSet) {
        withAnimation {
            offsets.map { programs[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("❌ Error deleting program: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ProgramRowView: View {
    let program: TrainingProgram
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(program.name ?? "Unnamed Program")
                    .font(.headline)
                    .bold()
                
                Spacer()
                
                Text("\(program.totalDays) days")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if let notes = program.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("Created \(dateFormatter.string(from: program.createdDate ?? Date()))", systemImage: "calendar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show the training day names
                if !program.sortedDayTemplates.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(program.sortedDayTemplates.prefix(3), id: \.self) { dayTemplate in
                            Text(dayTemplate.name ?? "Day")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        if program.sortedDayTemplates.count > 3 {
                            Text("+\(program.sortedDayTemplates.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProgramListView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 