import SwiftUI
import CoreData

struct ProgramDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var program: TrainingProgram
    
    @State private var showingCreateDayTemplate = false
    
    var body: some View {
        List {
            // Program info
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(program.name ?? "Unnamed Program")
                        .font(.title2)
                        .bold()
                    
                    if let notes = program.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("\(program.totalDays) training days", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Label("Created \(program.createdDate ?? Date(), style: .date)", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            if program.sortedDayTemplates.isEmpty {
                // Empty state
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.orange.opacity(0.6))
                        
                        Text("No training days yet")
                            .font(.headline)
                        
                        Text("Add your first training day template to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showingCreateDayTemplate = true
                        }) {
                            Text("Add Training Day")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
            } else {
                // Training day templates
                Section("Training Days") {
                    ForEach(program.sortedDayTemplates) { dayTemplate in
                        NavigationLink(destination: Text("Day Template Detail - Coming Soon")) {
                            DayTemplateRowView(dayTemplate: dayTemplate)
                        }
                    }
                    
                    Button(action: {
                        showingCreateDayTemplate = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.orange)
                            Text("Add Training Day")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Program")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCreateDayTemplate) {
            CreateDayTemplateView(program: program)
        }
    }
}

struct DayTemplateRowView: View {
    let dayTemplate: TrainingDayTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dayTemplate.name ?? "Unnamed Day")
                    .font(.headline)
                
                Spacer()
                
                Text("Day \(dayTemplate.order + 1)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if let notes = dayTemplate.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(dayTemplate.totalExercises) exercises", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let lastSession = dayTemplate.lastSession {
                    Label("Last: \(lastSession.date ?? Date(), style: .date)", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Never trained")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ProgramDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProgramDetailView(program: {
                let context = PersistenceController.preview.container.viewContext
                let program = TrainingProgram(context: context)
                program.name = "Push/Pull/Legs"
                program.notes = "6-day training program"
                program.createdDate = Date()
                return program
            }())
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 