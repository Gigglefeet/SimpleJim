import SwiftUI
import CoreData

struct BodyweightInputView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var trainingSession: TrainingSession
    @State private var bodyweight: Double
    @State private var bodyweightString: String
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    init(trainingSession: TrainingSession) {
        self.trainingSession = trainingSession
        self._bodyweight = State(initialValue: trainingSession.userBodyweight)
        self._bodyweightString = State(initialValue: String(format: "%.1f", trainingSession.userBodyweight))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Set Your Bodyweight")
                        .font(.title2)
                        .bold()
                    
                    Text("This will be used for bodyweight exercises like pullups and dips")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Bodyweight")
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            TextField("70.0", text: $bodyweightString)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .onChange(of: bodyweightString) { newValue in
                                    // Input validation: only allow positive numbers up to 500kg
                                    let filteredValue = newValue.filter { $0.isNumber || $0 == "." }
                                    if filteredValue != newValue {
                                        bodyweightString = filteredValue
                                        return
                                    }
                                    
                                    bodyweight = min(max(Double(filteredValue) ?? 70.0, 20.0), 500.0)
                                }
                            
                            Text("kg")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works:")
                            .font(.headline)
                        
                        Label("Toggle 'Bodyweight' for exercises like pullups", systemImage: "checkmark.circle")
                        Label("Add extra weight for weighted vests/belts", systemImage: "plus.circle")
                        Label("Total weight = Your bodyweight + extra weight", systemImage: "equal.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button(action: saveBodyweight) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        
                        Text(isSaving ? "Saving..." : "Save Bodyweight")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isSaving ? Color.orange.opacity(0.6) : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.headline)
                }
                .disabled(isSaving)
            }
            .padding()
            .navigationTitle("Bodyweight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Save Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveBodyweight() {
        isSaving = true
        trainingSession.userBodyweight = bodyweight
        
        do {
            try viewContext.save()
            #if DEBUG
            print("Saved bodyweight: \(bodyweight)kg")
            #endif
            dismiss()
        } catch {
            #if DEBUG
            print("Error saving bodyweight: \(error)")
            #endif
            
            // Show user-friendly error message
            errorMessage = "Failed to save your bodyweight. Please try again."
            showingErrorAlert = true
            isSaving = false
        }
    }
}

struct BodyweightInputView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let session = TrainingSession(context: context)
        session.userBodyweight = 75.0
        
        return BodyweightInputView(trainingSession: session)
            .environment(\.managedObjectContext, context)
    }
} 