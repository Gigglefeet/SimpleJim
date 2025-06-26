import SwiftUI
import CoreData

struct CreateDayTemplateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let program: TrainingProgram
    
    @State private var dayName = ""
    @State private var notes = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Day name (e.g., Push Day, Pull Day)", text: $dayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } header: {
                    Text("Training Day Details")
                }
                
                Section {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Add any specific notes about this training day")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's next:")
                            .font(.headline)
                        
                        Label("Add exercises to this day", systemImage: "plus.circle")
                        Label("Set target sets and reps", systemImage: "number.circle")
                        Label("Start training!", systemImage: "figure.strengthtraining.traditional")
                    }
                    .foregroundColor(.secondary)
                    .font(.caption)
                } header: {
                    Text("After Creating")
                }
            }
            .navigationTitle("New Training Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createDayTemplate()
                    }
                    .disabled(dayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createDayTemplate() {
        guard !dayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        
        let newDayTemplate = TrainingDayTemplate(context: viewContext)
        newDayTemplate.name = dayName.trimmingCharacters(in: .whitespacesAndNewlines)
        newDayTemplate.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        newDayTemplate.order = Int16(program.sortedDayTemplates.count)
        newDayTemplate.program = program
        
        do {
            try viewContext.save()
            print("✅ Created day template: \(newDayTemplate.name ?? "Unknown")")
            dismiss()
        } catch {
            let nsError = error as NSError
            print("❌ Error creating day template: \(nsError), \(nsError.userInfo)")
            isCreating = false
        }
    }
}

struct CreateDayTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        CreateDayTemplateView(program: {
            let context = PersistenceController.preview.container.viewContext
            let program = TrainingProgram(context: context)
            program.name = "Test Program"
            program.createdDate = Date()
            return program
        }())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 