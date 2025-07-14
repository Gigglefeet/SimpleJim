import SwiftUI
import CoreData

struct ProgramDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var program: TrainingProgram
    
    @State private var showingCreateDayTemplate = false
    @State private var editMode = EditMode.inactive
    @State private var editingProgramName = ""
    @State private var editingDayNames: [String: String] = [:]
    
    var body: some View {
        List {
            // Program info
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Editable program name
                    if editMode == .active {
                        TextField("Program name", text: $editingProgramName)
                            .font(.title2)
                            .bold()
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                saveProgramName()
                            }
                    } else {
                        Text(program.name ?? "Unnamed Program")
                            .font(.title2)
                            .bold()
                    }
                    
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
                        if editMode == .active {
                            // Editable day template row
                            EditableDayTemplateRowView(
                                dayTemplate: dayTemplate,
                                editingName: Binding(
                                    get: { editingDayNames[dayTemplate.objectID.uriRepresentation().absoluteString] ?? dayTemplate.name ?? "" },
                                    set: { editingDayNames[dayTemplate.objectID.uriRepresentation().absoluteString] = $0 }
                                ),
                                onSave: { newName in
                                    saveDayName(dayTemplate: dayTemplate, newName: newName)
                                }
                            )
                        } else {
                            // Regular navigation row
                            NavigationLink(destination: DayTemplateDetailView(dayTemplate: dayTemplate)) {
                                DayTemplateRowView(dayTemplate: dayTemplate)
                            }
                        }
                    }
                    .onMove(perform: editMode == .active ? moveDays : nil)
                    .onDelete(perform: editMode == .active ? deleteDays : nil)
                    
                    // Hide the add button when in edit mode to avoid confusion
                    if editMode == .inactive {
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
        }
        .navigationTitle("Program")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !program.sortedDayTemplates.isEmpty {
                    Button(editMode == .active ? "Done" : "Edit") {
                        withAnimation {
                            if editMode == .active {
                                // Save any pending changes before exiting edit mode
                                saveProgramName()
                                saveAllDayNames()
                            } else {
                                // Initialize editing state
                                initializeEditingState()
                            }
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateDayTemplate) {
            CreateDayTemplateView(program: program)
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeEditingState() {
        // Initialize program name
        editingProgramName = program.name ?? ""
        
        // Initialize day names
        editingDayNames.removeAll()
        for dayTemplate in program.sortedDayTemplates {
            let key = dayTemplate.objectID.uriRepresentation().absoluteString
            editingDayNames[key] = dayTemplate.name ?? ""
        }
    }
    
    private func saveProgramName() {
        let trimmedName = editingProgramName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName != program.name {
            program.name = trimmedName
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to save program name: \(error)")
                // Revert on error
                editingProgramName = program.name ?? ""
            }
        }
    }
    
    private func saveDayName(dayTemplate: TrainingDayTemplate, newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName != dayTemplate.name {
            dayTemplate.name = trimmedName
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to save day name: \(error)")
                // Revert on error
                let key = dayTemplate.objectID.uriRepresentation().absoluteString
                editingDayNames[key] = dayTemplate.name ?? ""
            }
        }
    }
    
    private func saveAllDayNames() {
        for dayTemplate in program.sortedDayTemplates {
            let key = dayTemplate.objectID.uriRepresentation().absoluteString
            if let editingName = editingDayNames[key] {
                saveDayName(dayTemplate: dayTemplate, newName: editingName)
            }
        }
    }
    
    private func moveDays(from source: IndexSet, to destination: Int) {
        withAnimation {
            var dayTemplates = program.sortedDayTemplates
            dayTemplates.move(fromOffsets: source, toOffset: destination)
            
            // Update the order in Core Data
            for (index, dayTemplate) in dayTemplates.enumerated() {
                dayTemplate.order = Int16(index)
            }
            
            do {
                try viewContext.save()
            } catch {
                // Handle error - could show an alert or log
                print("Failed to reorder days: \(error)")
            }
        }
    }
    
    private func deleteDays(offsets: IndexSet) {
        withAnimation {
            let dayTemplates = program.sortedDayTemplates
            
            // Delete the selected day templates
            for index in offsets {
                viewContext.delete(dayTemplates[index])
            }
            
            // Reorder the remaining day templates
            let remainingDays = dayTemplates.enumerated().compactMap { (idx, day) -> TrainingDayTemplate? in
                return offsets.contains(idx) ? nil : day
            }
            
            for (index, dayTemplate) in remainingDays.enumerated() {
                dayTemplate.order = Int16(index)
            }
            
            do {
                try viewContext.save()
            } catch {
                // Handle error - could show an alert or log
                print("Failed to delete days: \(error)")
            }
        }
    }
}

// MARK: - Editable Day Template Row

struct EditableDayTemplateRowView: View {
    let dayTemplate: TrainingDayTemplate
    @Binding var editingName: String
    let onSave: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Editable day name
                TextField("Day name", text: $editingName)
                    .font(.headline)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        onSave(editingName)
                    }
                
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