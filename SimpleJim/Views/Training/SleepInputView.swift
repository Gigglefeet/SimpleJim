import SwiftUI
import CoreData

struct SleepInputView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var trainingDay: TrainingDay
    @State private var sleepHours: Double
    
    init(trainingDay: TrainingDay) {
        self.trainingDay = trainingDay
        self._sleepHours = State(initialValue: trainingDay.sleepHours > 0 ? trainingDay.sleepHours : 8.0)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("How much sleep did you get?")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    Text("\(sleepHours, specifier: "%.1f") hours")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Slider(value: $sleepHours, in: 0...12, step: 0.5) {
                        Text("Sleep Hours")
                    } minimumValueLabel: {
                        Text("0h")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("12h")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accentColor(.blue)
                }
                .padding(.horizontal)
                
                // Quick selection buttons
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach([6.0, 7.0, 8.0, 9.0], id: \.self) { hours in
                        Button(action: {
                            sleepHours = hours
                        }) {
                            Text("\(hours, specifier: "%.0f")h")
                                .font(.headline)
                                .foregroundColor(sleepHours == hours ? .white : .blue)
                                .frame(width: 60, height: 40)
                                .background(sleepHours == hours ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                Text("Sleep quality affects recovery and performance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button(action: {
                    saveSleep()
                }) {
                    Text("Save Sleep")
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
    
    private func saveSleep() {
        withAnimation {
            trainingDay.sleepHours = sleepHours
            
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

struct SleepInputView_Previews: PreviewProvider {
    static var previews: some View {
        SleepInputView(trainingDay: PersistenceController.preview.container.viewContext.registeredObjects.first(where: { $0 is TrainingDay }) as! TrainingDay)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 