import SwiftUI
import CoreData

struct NutritionInputView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var trainingSession: TrainingSession
    @State private var proteinGrams: Double
    @State private var nutritionQuality: NutritionQuality = .good
    
    // Get user's protein goal from profile settings
    @AppStorage("proteinGoal") private var proteinGoal: Double = 150.0
    
    enum NutritionQuality: String, CaseIterable {
        case poor = "Poor"
        case fair = "Fair" 
        case good = "Good"
        case excellent = "Excellent"
        
        var emoji: String {
            switch self {
            case .poor: return "😵"
            case .fair: return "😐"
            case .good: return "😊"
            case .excellent: return "💪"
            }
        }
        
        var color: Color {
            switch self {
            case .poor: return .red
            case .fair: return .orange
            case .good: return .green
            case .excellent: return .blue
            }
        }
    }
    
    init(trainingSession: TrainingSession) {
        self.trainingSession = trainingSession
        self._proteinGrams = State(initialValue: trainingSession.proteinGrams)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Yesterday's Nutrition")
                        .font(.title2)
                        .bold()
                    
                    Text("How much protein did you consume yesterday?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 20) {
                    // Protein Grams Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Protein Intake")
                            .font(.headline)
                        
                        VStack(spacing: 16) {
                            // Visual protein display
                            HStack {
                                Text("\(Int(proteinGrams))gr")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.green)
                                
                                Spacer()
                                
                                Text(proteinQualityText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Protein grams slider
                            VStack(spacing: 8) {
                                Slider(value: $proteinGrams, in: 0...400, step: 5)
                                    .accentColor(.green)
                                
                                HStack {
                                    Text("0gr")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("400gr")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Nutrition Quality Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overall Nutrition Quality")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(NutritionQuality.allCases, id: \.self) { quality in
                                Button(action: {
                                    nutritionQuality = quality
                                }) {
                                    VStack(spacing: 8) {
                                        Text(quality.emoji)
                                            .font(.system(size: 30))
                                        
                                        Text(quality.rawValue)
                                            .font(.subheadline)
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 80)
                                    .background(nutritionQuality == quality ? quality.color.opacity(0.2) : Color(.systemGray6))
                                    .foregroundColor(nutritionQuality == quality ? quality.color : .primary)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(nutritionQuality == quality ? quality.color : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                    }
                    
                    // Quick protein buttons based on user's goal
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Select")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach([
                                    proteinGoal * 0.5,  // 50% of goal
                                    proteinGoal * 0.75, // 75% of goal
                                    proteinGoal,        // Goal
                                    proteinGoal * 1.25  // 125% of goal
                                ], id: \.self) { amount in
                                    Button(action: {
                                        proteinGrams = amount
                                    }) {
                                        Text("\(Int(amount))gr")
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(abs(proteinGrams - amount) < 5 ? Color.green : Color.gray.opacity(0.2))
                                            .foregroundColor(abs(proteinGrams - amount) < 5 ? .white : .primary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
                
                // Save Button
                Button(action: saveNutrition) {
                    Text("Save Nutrition Data")
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
            .navigationTitle("Nutrition")
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
    
    private var proteinQualityText: String {
        let goalRatio = proteinGrams / proteinGoal
        
        switch goalRatio {
        case 0..<0.5:
            return "Below target"
        case 0.5..<0.75:
            return "Getting there"
        case 0.75..<1.0:
            return "Close to goal"
        case 1.0..<1.25:
            return "Hit your goal!"
        case 1.25...:
            return "Exceeded goal!"
        default:
            return ""
        }
    }
    
    private func saveNutrition() {
        trainingSession.proteinGrams = proteinGrams
        
        do {
            try viewContext.save()
            #if DEBUG
            print("Nutrition data saved: \(Int(proteinGrams))gr protein")
            #endif
            dismiss()
        } catch {
            #if DEBUG
            print("Error saving nutrition data: \(error)")
            #endif
        }
    }
}

struct NutritionInputView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let session = TrainingSession(context: context)
        session.proteinGrams = 120
        
        return NutritionInputView(trainingSession: session)
            .environment(\.managedObjectContext, context)
    }
} 