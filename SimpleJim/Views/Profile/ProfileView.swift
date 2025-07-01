import SwiftUI

struct ProfileView: View {
    @State private var showingGoalsSheet = false
    @State private var showingExportSheet = false
    @State private var showingUnitsSheet = false
    @State private var notificationsEnabled = true
    
    // User defaults for settings
    @AppStorage("sleepGoal") private var sleepGoal: Double = 8.0
    @AppStorage("proteinGoal") private var proteinGoal: Double = 150.0
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    @AppStorage("preferredRestTime") private var preferredRestTime: Int = 90
    
    var body: some View {
        NavigationView {
            List {
                // User Stats Section
                Section("Your Progress") {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Keep up the great work!")
                                .font(.headline)
                            Text("Track your goals and preferences below")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Goals Section
                Section("Training Goals") {
                    Button(action: {
                        showingGoalsSheet = true
                    }) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Sleep & Nutrition Goals")
                                    .foregroundColor(.primary)
                                
                                Text("Sleep: \(Int(sleepGoal))h • Protein: \(Int(proteinGoal))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Default Rest Time")
                            Text("\(preferredRestTime) seconds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Stepper("", value: $preferredRestTime, in: 30...300, step: 15)
                            .labelsHidden()
                    }
                }
                
                // Settings Section
                Section("Preferences") {
                    Button(action: {
                        showingUnitsSheet = true
                    }) {
                        HStack {
                            Image(systemName: "scalemass")
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading) {
                                Text("Units & Display")
                                    .foregroundColor(.primary)
                                Text("Weight in \(weightUnit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    HStack {
                        Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash")
                            .foregroundColor(notificationsEnabled ? .orange : .gray)
                        
                        Text("Workout Reminders")
                        
                        Spacer()
                        
                        Toggle("", isOn: $notificationsEnabled)
                            .labelsHidden()
                    }
                }
                
                // Data Section
                Section("Data Management") {
                    Button(action: {
                        showingExportSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            
                            Text("Export Training Data")
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        // TODO: Implement import functionality
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.gray)
                            
                            Text("Import Data")
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("Coming Soon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true)
                }
                
                // About Section
                Section("About SimpleJim") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .foregroundColor(.orange)
                            
                            Text("SimpleJim")
                                .font(.headline)
                        }
                        
                        Text("Simple, effective gym tracking")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Version 1.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("Built with ❤️ for lifters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showingGoalsSheet) {
            GoalsSettingsView(sleepGoal: $sleepGoal, proteinGoal: $proteinGoal)
        }
        .sheet(isPresented: $showingUnitsSheet) {
            UnitsSettingsView(weightUnit: $weightUnit)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportDataView()
        }
    }
}

// MARK: - Supporting Views

struct GoalsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sleepGoal: Double
    @Binding var proteinGoal: Double
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sleep Goal") {
                    HStack {
                        Text("Target Sleep")
                        Spacer()
                        Text("\(Int(sleepGoal)) hours")
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $sleepGoal, in: 6...10, step: 0.5)
                }
                
                Section("Nutrition Goal") {
                    HStack {
                        Text("Daily Protein")
                        Spacer()
                        Text("\(Int(proteinGoal))g")
                            .foregroundColor(.green)
                    }
                    
                    Slider(value: $proteinGoal, in: 50...300, step: 10)
                }
            }
            .navigationTitle("Goals")
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
}

struct UnitsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weightUnit: String
    
    private let weightUnits = ["kg", "lbs"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Weight Units") {
                    Picker("Weight Unit", selection: $weightUnit) {
                        ForEach(weightUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Text("Changes will apply to new workouts. Existing data will not be converted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Units")
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
}

struct ExportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Export Your Data")
                    .font(.title2)
                    .bold()
                
                Text("Export your training data as a CSV file to backup or analyze your progress.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button(action: {
                    // TODO: Implement actual export functionality
                    isExporting = true
                    
                    // Simulate export delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isExporting = false
                        dismiss()
                    }
                }) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        
                        Text(isExporting ? "Exporting..." : "Export Data")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isExporting)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export")
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
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
} 