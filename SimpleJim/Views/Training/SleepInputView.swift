import SwiftUI
import CoreData

struct SleepInputView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var trainingSession: TrainingSession
    @State private var sleepHours: Double
    @State private var sleepQuality: SleepQuality = .good
    
    enum SleepQuality: String, CaseIterable {
        case poor = "Poor"
        case fair = "Fair" 
        case good = "Good"
        case excellent = "Excellent"
        
        var emoji: String {
            switch self {
            case .poor: return "😴"
            case .fair: return "😐"
            case .good: return "😊"
            case .excellent: return "🌟"
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
        self._sleepHours = State(initialValue: trainingSession.sleepHours)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Sleep Tracking")
                        .font(.title2)
                        .bold()
                    
                    Text("How did you sleep before this workout?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 20) {
                    // Sleep Hours Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hours of Sleep")
                            .font(.headline)
                        
                        VStack(spacing: 16) {
                            // Visual sleep hours display
                            HStack {
                                Text("\(sleepHours, specifier: "%.1f") hours")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                Text(sleepQualityText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Sleep hours slider
                            VStack(spacing: 8) {
                                Slider(value: $sleepHours, in: 0...12, step: 0.5)
                                    .accentColor(.blue)
                                
                                HStack {
                                    Text("0h")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("12h")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Sleep Quality Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleep Quality")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(SleepQuality.allCases, id: \.self) { quality in
                                Button(action: {
                                    sleepQuality = quality
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
                                    .background(sleepQuality == quality ? quality.color.opacity(0.2) : Color(.systemGray6))
                                    .foregroundColor(sleepQuality == quality ? quality.color : .primary)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(sleepQuality == quality ? quality.color : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                    }
                    
                    // Quick sleep buttons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Select")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach([6.0, 7.0, 8.0, 9.0], id: \.self) { hours in
                                    Button(action: {
                                        sleepHours = hours
                                    }) {
                                        Text("\(Int(hours))h")
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(sleepHours == hours ? Color.blue : Color.gray.opacity(0.2))
                                            .foregroundColor(sleepHours == hours ? .white : .primary)
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
                Button(action: saveSleep) {
                    Text("Save Sleep Data")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Sleep")
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
    
    private var sleepQualityText: String {
        switch sleepHours {
        case 0..<5:
            return "Too little sleep"
        case 5..<6:
            return "Poor sleep"
        case 6..<7:
            return "Below average"
        case 7..<8:
            return "Good sleep"
        case 8..<9:
            return "Great sleep"
        case 9...:
            return "Plenty of sleep"
        default:
            return ""
        }
    }
    
    private func saveSleep() {
        trainingSession.sleepHours = sleepHours
        
        do {
            try viewContext.save()
            print("✅ Sleep data saved: \(sleepHours) hours")
            dismiss()
        } catch {
            print("❌ Error saving sleep data: \(error)")
        }
    }
}

struct SleepInputView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let session = TrainingSession(context: context)
        session.sleepHours = 7.5
        
        return SleepInputView(trainingSession: session)
            .environment(\.managedObjectContext, context)
    }
} 