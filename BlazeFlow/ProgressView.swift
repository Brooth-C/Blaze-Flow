import SwiftUI
import Charts

struct ProgressView: View {
    @Environment(FocusStore.self) private var store

    private var week: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (-6...0).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Small steps.\nReal progress.").font(.largeTitle.bold())
                DailyGoalCard()
                HStack(spacing: 16) {
                    metric("Goal streak", value: "\(store.data.streak(asOf: Date())) days", icon: "flame.fill")
                    metric("Completed", value: "\(store.data.history.filter(\.completed).count)", icon: "checkmark.circle")
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your last 7 days").font(.headline)
                    Chart {
                        ForEach(week, id: \.self) { day in
                            BarMark(
                                x: .value("Day", day, unit: .day),
                                y: .value("Focus minutes", store.data.minutes(on: day))
                            )
                            .foregroundStyle(.orange.gradient).cornerRadius(5)
                            .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityValue("\(store.data.minutes(on: day)) minutes")
                        }
                        RuleMark(y: .value("Daily goal", store.data.dailyGoalMinutes))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(dash: [4]))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxisLabel("Minutes")
                    .frame(height: 200)
                    Text("The dashed line marks your current daily goal. Changing your goal recalculates your streak.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .focusCard()
                Text("Recent sessions").font(.title2.bold())
                if store.data.history.isEmpty {
                    ContentUnavailableView("Your first step starts here", systemImage: "leaf", description: Text("Finish a focus session to see your progress."))
                } else {
                    VStack(spacing: 16) {
                        ForEach(Array(store.data.history.reversed().prefix(20))) { session in
                            HStack {
                                Image(systemName: session.completed ? "checkmark.circle.fill" : "pause.circle")
                                    .foregroundStyle(session.completed ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.completed ? "Session completed" : "Session ended early")
                                        .font(.subheadline.weight(.semibold))
                                    Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(max(0, Int(session.finishedAt.timeIntervalSince(session.startedAt) / 60))) min")
                                    .font(.subheadline).monospacedDigit()
                            }
                        }
                    }
                    .focusCard()
                }
                Text("Focus time records your sessions, including time before ending early. It does not measure total screen time or verify what you did during a session.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
        .onAppear { store.refresh() }
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(.orange)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).focusCard()
    }
}
