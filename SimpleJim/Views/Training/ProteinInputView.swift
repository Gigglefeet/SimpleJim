import SwiftUI
import CoreData

struct ProteinInputView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var trainingDay: TrainingDay
    @State private var proteinGrams: Double
    
    init(trainingDay: TrainingDay) {
        self.trainingDay = trainingDay
        self._proteinGrams = State(initialValue: trainingDay.proteinGrams > 0 ? trainingDay.proteinGrams : 150.0)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("How much protein did you eat?")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    Text("\(Int(proteinGrams))g")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Slider(value: $proteinGrams, in: 0...300, step: 5) {
                        Text("Protein Grams")
                    } minimumValueLabel: {
                        Text("0g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("300g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accentColor(.green)
                }
                .padding(.horizontal)
                
                // Quick selection buttons
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach([100, 125, 150, 175, 200, 225, 250, 275], id: \.self) { grams in
                        Button(action: {
                            proteinGrams = Double(grams)
                        }) {
                            Text("\(grams)g")
                                .font(.headline)
                                .foregroundColor(Int(proteinGrams) == grams ? .white : .green)
                                .frame(width: 60, height: 40)
                                .background(Int(proteinGrams) == grams ? Color.green : Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                Text("Adequate protein supports muscle recovery and growth")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button(action: {
                    saveProtein()
                }) {
                    Text("Save Protein")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Protein")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveProtein() {
        withAnimation {
            trainingDay.proteinGrams = proteinGrams
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ProteinInputView_Previews: PreviewProvider {
    static var previews: some View {
        ProteinInputView(trainingDay: PersistenceController.preview.container.viewContext.registeredObjects.first(where: { $0 is TrainingDay }) as! TrainingDay)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 