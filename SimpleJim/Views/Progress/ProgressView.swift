import SwiftUI
import CoreData
import Charts

struct ProgressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
        animation: .default)
    private var trainingSessions: FetchedResults<TrainingSession>
    
    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedExercise: String = "All Exercises"
    @State private var selectedProgram: String = "All Programs"
    
    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case threeMonths = "3 Months"
        case year = "1 Year"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            case .all: return 0
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Stats
                    quickStatsSection
                    
                    // Time Range Picker
                    timeRangePicker
                    
                    // Program Filter
                    programPicker
                    
                    // Total Weight Progress Chart
                    totalWeightChart
                    
                    // Exercise Progress Chart
                    exerciseProgressChart
                    
                    // Muscle Group Distribution
                    muscleGroupChart
                    
                    // Recent Sessions List
                    recentSessionsList
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }
    
    private var quickStatsSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Training Overview")
                        .font(.title2)
                        .bold()
                    
                    if selectedProgram != "All Programs" {
                        Text(selectedProgram)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Sessions",
                    value: "\(filteredSessions.count)",
                    icon: "figure.strengthtraining.traditional",
                    color: .orange
                )
                
                StatCard(
                    title: "Total Weight",
                    value: "\(Int(totalWeightLifted))kg",
                    icon: "scalemass",
                    color: .blue
                )
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Avg Duration",
                    value: averageDurationFormatted,
                    icon: "clock",
                    color: .green
                )
                
                StatCard(
                    title: "Best Session",
                    value: "\(Int(bestSession))kg",
                    icon: "trophy",
                    color: .purple
                )
            }
        }
    }
    
    private var timeRangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Range")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedTimeRange = range
                        }) {
                            Text(range.rawValue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedTimeRange == range ? Color.orange : Color.gray.opacity(0.2))
                                .foregroundColor(selectedTimeRange == range ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var programPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training Program")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // All Programs option
                    Button(action: {
                        selectedProgram = "All Programs"
                    }) {
                        Text("All Programs")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedProgram == "All Programs" ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedProgram == "All Programs" ? .white : .primary)
                            .cornerRadius(20)
                    }
                    
                    // Individual programs
                    ForEach(uniqueProgramNames.sorted(), id: \.self) { program in
                        Button(action: {
                            selectedProgram = program
                        }) {
                            Text(program)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedProgram == program ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedProgram == program ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @available(iOS 16.0, *)
    private var totalWeightChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Weight Lifted Over Time")
                .font(.headline)
            
            if filteredSessions.isEmpty {
                emptyStateView
            } else {
                Chart(weightProgressData) { data in
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Weight", data.weight)
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", data.date),
                        y: .value("Weight", data.weight)
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: chartXAxisStride)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @available(iOS 16.0, *)
    private var exerciseProgressChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exercise Progress")
                    .font(.headline)
                
                Spacer()
                
                Menu(selectedExercise) {
                    Button("All Exercises") {
                        selectedExercise = "All Exercises"
                    }
                    
                    ForEach(uniqueExerciseNames.sorted(), id: \.self) { exercise in
                        Button(exercise) {
                            selectedExercise = exercise
                        }
                    }
                }
                .foregroundColor(.orange)
            }
            
            if exerciseProgressData.isEmpty {
                emptyStateView
            } else {
                Chart(exerciseProgressData) { data in
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Max Weight", data.maxWeight)
                    )
                    .foregroundStyle(by: .value("Exercise", data.exerciseName))
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: chartXAxisStride)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @available(iOS 16.0, *)
    private var muscleGroupChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight by Muscle Group")
                .font(.headline)
            
            if muscleGroupData.isEmpty {
                emptyStateView
            } else {
                Chart(muscleGroupData) { data in
                    BarMark(
                        x: .value("Weight", data.weight),
                        y: .value("Muscle Group", data.muscleGroup)
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: max(200, CGFloat(muscleGroupData.count * 30)))
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(.headline)
            
            if filteredSessions.isEmpty {
                emptyStateView
            } else {
                ForEach(Array(filteredSessions.prefix(5)), id: \.objectID) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.template?.name ?? "Unknown Workout")
                                .font(.headline)
                            
                            Text(session.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(session.totalWeightLifted))kg")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            HStack(spacing: 8) {
                                Text("\(session.totalSets) sets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(session.durationFormatted)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 40))
                .foregroundColor(.orange.opacity(0.6))
            
            Text("No training data yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Complete some workouts to see your progress")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 150)
    }
    
    // MARK: - Computed Properties
    
    private var filteredSessions: [TrainingSession] {
        var sessions = Array(trainingSessions)
        
        // Filter by program
        if selectedProgram != "All Programs" {
            sessions = sessions.filter { session in
                session.template?.program?.name == selectedProgram
            }
        }
        
        // Filter by time range
        if selectedTimeRange != .all {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
            sessions = sessions.filter { session in
                (session.date ?? Date()) >= cutoffDate
            }
        }
        
        return sessions
    }
    
    private var totalWeightLifted: Double {
        filteredSessions.reduce(0) { total, session in
            total + session.totalWeightLifted
        }
    }
    
    private var averageWeightPerSession: Double {
        guard !filteredSessions.isEmpty else { return 0 }
        return totalWeightLifted / Double(filteredSessions.count)
    }
    
    private var bestSession: Double {
        filteredSessions.map { $0.totalWeightLifted }.max() ?? 0
    }
    
    private var averageDuration: TimeInterval {
        let completedSessions = filteredSessions.filter { $0.endTime != nil }
        guard !completedSessions.isEmpty else { return 0 }
        
        let totalDuration = completedSessions.reduce(0) { total, session in
            total + session.duration
        }
        return totalDuration / Double(completedSessions.count)
    }
    
    private var averageDurationFormatted: String {
        let totalSeconds = Int(averageDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var chartXAxisStride: Int {
        switch selectedTimeRange {
        case .week: return 1
        case .month: return 5
        case .threeMonths: return 15
        case .year: return 30
        case .all: return 30
        }
    }
    
    private var weightProgressData: [WeightProgressData] {
        filteredSessions.reversed().map { session in
            WeightProgressData(
                date: session.date ?? Date(),
                weight: session.totalWeightLifted
            )
        }
    }
    
    private var exerciseProgressData: [ExerciseProgressData] {
        var data: [ExerciseProgressData] = []
        
        let exercises = selectedExercise == "All Exercises" ? uniqueExerciseNames : [selectedExercise]
        
        for exercise in exercises {
            let exerciseData = filteredSessions.reversed().compactMap { session -> ExerciseProgressData? in
                guard let completedExercise = session.sortedCompletedExercises.first(where: { 
                    $0.template?.name == exercise 
                }) else { return nil }
                
                let maxWeight = completedExercise.sets.map { $0.weight }.max() ?? 0
                guard maxWeight > 0 else { return nil }
                
                return ExerciseProgressData(
                    date: session.date ?? Date(),
                    exerciseName: exercise,
                    maxWeight: maxWeight
                )
            }
            data.append(contentsOf: exerciseData)
        }
        
        return data
    }
    
    private var muscleGroupData: [MuscleGroupData] {
        var groupWeights: [String: Double] = [:]
        
        for session in filteredSessions {
            for completedExercise in session.sortedCompletedExercises {
                let muscleGroup = completedExercise.template?.muscleGroup ?? "Unknown"
                let weight = completedExercise.totalWeight
                groupWeights[muscleGroup, default: 0] += weight
            }
        }
        
        return groupWeights.map { (group, weight) in
            MuscleGroupData(muscleGroup: group, weight: weight)
        }.sorted { $0.weight > $1.weight }
    }
    
    private var uniqueExerciseNames: Set<String> {
        Set(filteredSessions.flatMap { session in
            session.sortedCompletedExercises.compactMap { $0.template?.name }
        })
    }
    
    private var uniqueProgramNames: Set<String> {
        Set(Array(trainingSessions).compactMap { session in
            session.template?.program?.name
        })
    }
}

// MARK: - Data Models

struct WeightProgressData: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}

struct ExerciseProgressData: Identifiable {
    let id = UUID()
    let date: Date
    let exerciseName: String
    let maxWeight: Double
}

struct MuscleGroupData: Identifiable {
    let id = UUID()
    let muscleGroup: String
    let weight: Double
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .bold()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 