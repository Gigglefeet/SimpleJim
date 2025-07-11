import SwiftUI
import CoreData

struct BodyweightInputView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var trainingSession: TrainingSession
    @State private var bodyweight: Double
    @State private var bodyweightString: String
    
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
                
                Button("Save Bodyweight") {
                    saveBodyweight()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
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
        }
    }
    
    private func saveBodyweight() {
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