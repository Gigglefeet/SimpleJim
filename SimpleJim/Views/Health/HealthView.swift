import SwiftUI
import CoreData

struct HealthView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
        animation: .default)
    private var trainingSessions: FetchedResults<TrainingSession>
    
    @State private var selectedDate = Date()
    @State private var showWorkoutOverlay = false
    @State private var viewMode: ViewMode = .month
    @State private var showingDetailSheet = false
    @State private var selectedDayData: DayData?
    @State private var selectedSession: TrainingSession?
    
    // Get user's goals from profile settings
    @AppStorage("sleepGoal") private var sleepGoal: Double = 8.0
    @AppStorage("proteinGoal") private var proteinGoal: Double = 150.0
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    
    enum ViewMode: String, CaseIterable {
        case month = "Month"
        case week = "Week"
        
        var systemImage: String {
            switch self {
            case .month: return "calendar"
            case .week: return "calendar.day.timeline.leading"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with controls
                headerSection
                
                // Calendar content
                ScrollView {
                    VStack(spacing: 20) {
                        if viewMode == .month {
                            monthCalendarView
                        } else {
                            weekTimelineView
                        }
                        
                        // Summary stats
                        summaryStatsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingDetailSheet) {
            if let dayData = selectedDayData {
                DayDetailView(dayData: dayData, session: selectedSession)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                // View mode picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
            }
            
            HStack {
                // Workout overlay toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showWorkoutOverlay.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: showWorkoutOverlay ? "eye.fill" : "eye.slash.fill")
                            .font(.caption)
                        
                        Text(showWorkoutOverlay ? "Hide Workouts" : "Show Workouts")
                            .font(.subheadline)
                            .bold()
                    }
                    .foregroundColor(showWorkoutOverlay ? .orange : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showWorkoutOverlay ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(16)
                }
                
                Spacer()
                
                // Month navigation
                HStack(spacing: 12) {
                    Button(action: { changeMonth(-1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.orange)
                    }
                    
                    Text(selectedDate, style: .date)
                        .font(.headline)
                        .bold()
                    
                    Button(action: { changeMonth(1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var monthCalendarView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            // Day headers
            ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                Text(day.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(height: 20)
            }
            
            // Calendar days
            ForEach(calendarDays, id: \.date) { dayData in
                CalendarDayView(
                    dayData: dayData,
                    showWorkoutOverlay: showWorkoutOverlay,
                    sleepGoal: sleepGoal,
                    proteinGoal: proteinGoal
                )
                .onTapGesture {
                    selectedDayData = dayData
                    selectedSession = getTrainingSession(for: dayData.date)
                    showingDetailSheet = true
                }
            }
        }
    }
    
    private var weekTimelineView: some View {
        VStack(spacing: 16) {
            ForEach(weekDays, id: \.date) { dayData in
                WeekDayRowView(
                    dayData: dayData,
                    showWorkoutOverlay: showWorkoutOverlay,
                    sleepGoal: sleepGoal,
                    proteinGoal: proteinGoal
                )
                .onTapGesture {
                    selectedDayData = dayData
                    selectedSession = getTrainingSession(for: dayData.date)
                    showingDetailSheet = true
                }
            }
        }
    }
    
    
    
    private var summaryStatsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("This Month")
                    .font(.headline)
                    .bold()
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Avg Sleep",
                    value: String(format: "%.1fh", monthlyAverageSleep),
                    icon: "moon.stars.fill",
                    color: sleepAchievementColor
                )
                
                StatCard(
                    title: "Avg Protein",
                    value: "\(Int(monthlyAverageProtein))g",
                    icon: "fork.knife.circle.fill",
                    color: proteinAchievementColor
                )
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Sleep Streak",
                    value: "\(sleepStreak) days",
                    icon: "flame.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Protein Streak",
                    value: "\(proteinStreak) days",
                    icon: "flame.fill",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func changeMonth(_ direction: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = Calendar.current.date(byAdding: .month, value: direction, to: selectedDate) ?? selectedDate
        }
    }
    
    // MARK: - Computed Properties
    
    private var calendarDays: [DayData] {
        generateCalendarDays(for: selectedDate)
    }
    
    private var weekDays: [DayData] {
        generateWeekDays(for: selectedDate)
    }
    
    private var monthlyAverageSleep: Double {
        let monthSessions = sessionsInMonth(selectedDate)
        let validSessions = monthSessions.filter { $0.sleepHours > 0 }
        guard !validSessions.isEmpty else { return 0 }
        return validSessions.reduce(0) { $0 + $1.sleepHours } / Double(validSessions.count)
    }
    
    private var monthlyAverageProtein: Double {
        let monthSessions = sessionsInMonth(selectedDate)
        let validSessions = monthSessions.filter { $0.proteinGrams > 0 }
        guard !validSessions.isEmpty else { return 0 }
        return validSessions.reduce(0) { $0 + $1.proteinGrams } / Double(validSessions.count)
    }
    
    private var sleepAchievementColor: Color {
        monthlyAverageSleep >= sleepGoal ? .green : monthlyAverageSleep >= sleepGoal * 0.8 ? .orange : .red
    }
    
    private var proteinAchievementColor: Color {
        monthlyAverageProtein >= proteinGoal ? .green : monthlyAverageProtein >= proteinGoal * 0.8 ? .orange : .red
    }
    
    private var sleepStreak: Int {
        calculateStreak(for: \.sleepHours, goal: sleepGoal)
    }
    
    private var proteinStreak: Int {
        calculateStreak(for: \.proteinGrams, goal: proteinGoal)
    }
    
    // MARK: - Data Generation Methods
    
    private func generateCalendarDays(for date: Date) -> [DayData] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let endOfMonth = calendar.dateInterval(of: .month, for: date)?.end ?? date
        
        // Get first day of week for the month
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysFromPreviousMonth = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [DayData] = []
        
        // Add days from previous month (if needed)
        for i in 0..<daysFromPreviousMonth {
            let day = calendar.date(byAdding: .day, value: i - daysFromPreviousMonth, to: startOfMonth) ?? startOfMonth
            days.append(createDayData(for: day, isCurrentMonth: false))
        }
        
        // Add days from current month
        var currentDay = startOfMonth
        while currentDay < endOfMonth {
            days.append(createDayData(for: currentDay, isCurrentMonth: true))
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
        }
        
        // Add days from next month to complete the grid
        while days.count < 42 { // 6 weeks * 7 days
            days.append(createDayData(for: currentDay, isCurrentMonth: false))
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
        }
        
        return days
    }
    
    private func generateWeekDays(for date: Date) -> [DayData] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        
        var days: [DayData] = []
        var currentDay = startOfWeek
        
        for _ in 0..<7 {
            days.append(createDayData(for: currentDay, isCurrentMonth: true))
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
        }
        
        return days
    }
    
    private func createDayData(for date: Date, isCurrentMonth: Bool) -> DayData {
        let session = getTrainingSession(for: date)
        
        return DayData(
            date: date,
            sleepHours: session?.sleepHours ?? 0,
            proteinGrams: session?.proteinGrams ?? 0,
            hasWorkout: session != nil,
            totalWeight: session?.totalWeightLifted ?? 0,
            workoutDuration: session?.duration ?? 0,
            exerciseCount: session?.sortedCompletedExercises.count ?? 0,
            isCurrentMonth: isCurrentMonth,
            dayTemplate: session?.template
        )
    }
    
    private func getTrainingSession(for date: Date) -> TrainingSession? {
        let calendar = Calendar.current
        return trainingSessions.first { session in
            guard let sessionDate = session.date else { return false }
            return calendar.isDate(sessionDate, inSameDayAs: date)
        }
    }
    
    private func sessionsInMonth(_ date: Date) -> [TrainingSession] {
        let calendar = Calendar.current
        return trainingSessions.filter { session in
            guard let sessionDate = session.date else { return false }
            return calendar.isDate(sessionDate, equalTo: date, toGranularity: .month)
        }
    }
    
    private func calculateStreak(for keyPath: KeyPath<TrainingSession, Double>, goal: Double) -> Int {
        let calendar = Calendar.current
        let sortedSessions = trainingSessions.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
        
        var streak = 0
        let currentDate = Date()
        
        for i in 0..<30 { // Check last 30 days
            let checkDate = calendar.date(byAdding: .day, value: -i, to: currentDate) ?? currentDate
            
            if let session = sortedSessions.first(where: { 
                guard let sessionDate = $0.date else { return false }
                return calendar.isDate(sessionDate, inSameDayAs: checkDate)
            }) {
                if session[keyPath: keyPath] >= goal {
                    streak += 1
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return streak
    }
}

// MARK: - Data Models

struct DayData {
    let date: Date
    let sleepHours: Double
    let proteinGrams: Double
    let hasWorkout: Bool
    let totalWeight: Double
    let workoutDuration: TimeInterval
    let exerciseCount: Int
    let isCurrentMonth: Bool
    let dayTemplate: TrainingDayTemplate?
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let dayData: DayData
    let showWorkoutOverlay: Bool
    let sleepGoal: Double
    let proteinGoal: Double
    
    private var dayNumber: String {
        String(Calendar.current.component(.day, from: dayData.date))
    }
    
    private var sleepAchieved: Bool {
        dayData.sleepHours >= sleepGoal
    }
    
    private var proteinAchieved: Bool {
        dayData.proteinGrams >= proteinGoal
    }
    
    private var backgroundColor: Color {
        if !dayData.isCurrentMonth {
            return Color.clear
        }
        
        if showWorkoutOverlay && dayData.hasWorkout {
            return Color.orange.opacity(0.3)
        }
        
        let sleepRatio = dayData.sleepHours > 0 ? dayData.sleepHours / sleepGoal : 0
        let proteinRatio = dayData.proteinGrams > 0 ? dayData.proteinGrams / proteinGoal : 0
        
        if sleepRatio >= 1.0 && proteinRatio >= 1.0 {
            return Color.green.opacity(0.3)
        } else if sleepRatio >= 0.8 && proteinRatio >= 0.8 {
            return Color.yellow.opacity(0.3)
        } else if sleepRatio > 0 || proteinRatio > 0 {
            return Color.red.opacity(0.2)
        }
        
        return Color.clear
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(dayData.isCurrentMonth ? .primary : .secondary)
            
            if dayData.isCurrentMonth {
                VStack(spacing: 1) {
                    if dayData.sleepHours > 0 {
                        Text(String(format: "%.1fh", dayData.sleepHours))
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if dayData.proteinGrams > 0 {
                        Text("\(Int(dayData.proteinGrams))g")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    if showWorkoutOverlay && dayData.hasWorkout {
                        Text("🏋️")
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(width: 40, height: 50)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Calendar.current.isDateInToday(dayData.date) ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Week Day Row View

struct WeekDayRowView: View {
    let dayData: DayData
    let showWorkoutOverlay: Bool
    let sleepGoal: Double
    let proteinGoal: Double
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: dayData.date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: dayData.date)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayName)
                    .font(.headline)
                    .bold()
                
                Text(dayNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    if dayData.sleepHours > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.stars.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text(String(format: "%.1fh", dayData.sleepHours))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if dayData.proteinGrams > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "fork.knife.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text("\(Int(dayData.proteinGrams))g")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                if showWorkoutOverlay && dayData.hasWorkout {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("\(Int(Units.kgToDisplay(dayData.totalWeight, unit: weightUnit)))\(Units.unitSuffix(weightUnit)) • \(dayData.exerciseCount) exercises")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Day Detail View

struct DayDetailView: View {
    let dayData: DayData
    let session: TrainingSession?
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: dayData.date)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Health Metrics")
                            .font(.headline)
                            .bold()
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "moon.stars.fill")
                                        .foregroundColor(.blue)
                                    Text("Sleep")
                                        .font(.subheadline)
                                        .bold()
                                }
                                
                                Text(dayData.sleepHours > 0 ? String(format: "%.1f hours", dayData.sleepHours) : "Not logged")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(dayData.sleepHours > 0 ? .blue : .secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "fork.knife.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Protein")
                                        .font(.subheadline)
                                        .bold()
                                }
                                
                                Text(dayData.proteinGrams > 0 ? "\(Int(dayData.proteinGrams))g" : "Not logged")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(dayData.proteinGrams > 0 ? .green : .secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    if dayData.hasWorkout {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Workout Summary")
                                .font(.headline)
                                .bold()
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Training Day:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(dayData.dayTemplate?.name ?? "Unknown")
                                        .bold()
                                }
                                
                                HStack {
                                    Text("Total Weight:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(Units.kgToDisplay(dayData.totalWeight, unit: weightUnit)))\(Units.unitSuffix(weightUnit))")
                                        .bold()
                                        .foregroundColor(.orange)
                                }
                                
                                HStack {
                                    Text("Exercises:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(dayData.exerciseCount)")
                                        .bold()
                                }
                                
                                if dayData.workoutDuration > 0 {
                                    HStack {
                                        Text("Duration:")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(formatDuration(dayData.workoutDuration))
                                            .bold()
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                if let session = session {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            Text("View Workout")
                        }
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct HealthView_Previews: PreviewProvider {
    static var previews: some View {
        HealthView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 