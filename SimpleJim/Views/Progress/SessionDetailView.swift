import SwiftUI
import CoreData

struct SessionDetailView: View {
    @ObservedObject var session: TrainingSession
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    
    private var titleText: String {
        session.template?.name ?? "Workout"
    }
    
    // MARK: - Drop cluster helpers
    struct SDCluster: Identifiable {
        let id: String
        let sets: [ExerciseSet]
        let isDrop: Bool
        func summary(weightUnit: String) -> String {
            let parts = sets.map { set in
                let w = Int(Units.kgToDisplay(set.effectiveWeight, unit: weightUnit))
                return "\(w)\(Units.unitSuffix(weightUnit))×\(set.reps)"
            }
            return parts.joined(separator: " → ")
        }
    }
    private func buildClusters(_ sets: [ExerciseSet]) -> [SDCluster] {
        var items: [SDCluster] = []
        var i = 0
        while i < sets.count {
            let s = sets[i]
            if s.restSeconds < 0 {
                var g: [ExerciseSet] = [s]
                var j = i + 1
                while j < sets.count && sets[j].restSeconds < 0 {
                    g.append(sets[j]); j += 1
                }
                items.append(SDCluster(id: s.objectID.uriRepresentation().absoluteString, sets: g, isDrop: true))
                i = j
            } else {
                items.append(SDCluster(id: s.objectID.uriRepresentation().absoluteString, sets: [s], isDrop: false))
                i += 1
            }
        }
        return items
    }
    
    private var subtitleText: String {
        let dateString = session.date?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown"
        return dateString
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                exercises
                footer
            }
            .padding()
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitleText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                stat("Total Weight", "\(Int(Units.kgToDisplay(session.totalWeightLifted, unit: weightUnit)))\(Units.unitSuffix(weightUnit))", color: .orange, icon: "scalemass")
                stat("Duration", session.durationFormatted, color: .green, icon: "clock")
            }
            
            if session.userBodyweight > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    Text("Bodyweight: \(Int(Units.kgToDisplay(session.userBodyweight, unit: weightUnit)))\(Units.unitSuffix(weightUnit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                if session.sleepHours > 0 {
                    stat("Sleep", String(format: "%.1fh", session.sleepHours), color: .blue, icon: "moon.stars.fill")
                }
                if session.proteinGrams > 0 {
                    stat("Protein", "\(Int(session.proteinGrams))g", color: .green, icon: "fork.knife.circle.fill")
                }
            }
        }
    }
    
    private func stat(_ title: String, _ value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var exercises: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
            
            if session.sortedCompletedExercises.isEmpty {
                Text("No exercise data")
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(session.sortedCompletedExercises, id: \.objectID) { completed in
                        exerciseCard(completed)
                    }
                }
            }
        }
    }
    
    private func exerciseCard(_ completed: CompletedExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(completed.template?.name ?? "Exercise")
                    .font(.headline)
                Spacer()
                Text("\(completed.completedSets)/\(completed.totalSets) sets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Compact list of sets (group drop clusters)
            VStack(alignment: .leading, spacing: 6) {
                let items = buildClusters(completed.sets)
                ForEach(items, id: \.id) { item in
                    if item.isDrop {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Drop set")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(item.summary(weightUnit: weightUnit))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(item.sets, id: \.objectID) { set in
                                HStack(spacing: 8) {
                                    Text(set.isBodyweight ? "BW" : "\(Int(Units.kgToDisplay(set.effectiveWeight, unit: weightUnit)))\(Units.unitSuffix(weightUnit))")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .frame(width: 60, alignment: .leading)
                                    Text("×").foregroundColor(.secondary)
                                    Text("\(set.reps)").font(.caption).foregroundColor(.primary)
                                    if set.isCompleted { Spacer(); Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                                }
                            }
                        }
                    } else if let set = item.sets.first {
                        HStack(spacing: 8) {
                            Text(set.isBodyweight ? "BW" : "\(Int(Units.kgToDisplay(set.effectiveWeight, unit: weightUnit)))\(Units.unitSuffix(weightUnit))")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .frame(width: 60, alignment: .leading)
                            Text("×").foregroundColor(.secondary)
                            Text("\(set.reps)").font(.caption).foregroundColor(.primary)
                            if set.isCompleted { Spacer(); Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let start = session.startTime {
                Text("Started: \(start.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let end = session.endTime {
                Text("Finished: \(end.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }
}


