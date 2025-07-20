import SwiftUI
import CoreData
import os.log

struct CreateProgramView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var programName = ""
    @State private var programNotes = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Program Details") {
                    TextField("Program name", text: $programName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description (optional)", text: $programNotes, axis: .vertical)
                        .lineLimit(3)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Getting Started") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("After creating your program, you'll be able to:")
                            .font(.subheadline)
                            .bold()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Add training day templates", systemImage: "calendar.badge.plus")
                            Label("Define exercises for each day", systemImage: "list.bullet")
                            Label("Start workouts based on your templates", systemImage: "play.circle")
                            Label("Track progress over time", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(action: createProgram) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isCreating ? "Creating..." : "Create Program")
                        }
                    }
                    .disabled(programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createProgram() {
        isCreating = true
        
        withAnimation {
            let newProgram = TrainingProgram(context: viewContext)
            newProgram.name = programName.trimmingCharacters(in: .whitespacesAndNewlines)
            newProgram.notes = programNotes.isEmpty ? nil : programNotes
            newProgram.createdDate = Date()
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                os_log("Failed to create program: %@", log: .default, type: .error, error.localizedDescription)
                errorMessage = "Failed to create program. Please try again."
                showingErrorAlert = true
                isCreating = false
            }
        }
    }
}

struct CreateProgramView_Previews: PreviewProvider {
    static var previews: some View {
        CreateProgramView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 