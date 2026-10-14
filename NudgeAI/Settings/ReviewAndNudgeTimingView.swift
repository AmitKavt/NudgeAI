import SwiftUI

/// Matches Figma node 9:211.
struct ReviewAndNudgeTimingView: View {
    let settingsRepository: SettingsRepository
    @Environment(\.dismiss) private var dismiss

    @State private var reviewTime = Date()
    @State private var isCustomTime = false
    @State private var leadTimeFirstDays = 15
    @State private var leadTimeSecondDays = 5
    @State private var dueDateCheckInEnabled = true
    @State private var quietHoursEnabled = true
    @State private var quietHoursStart = Date()
    @State private var quietHoursEnd = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "Review and nudges", onBack: { dismiss() })

                GroupedCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionEyebrow(text: "NIGHTLY REVIEW")
                        Text(reviewTime.formatted(date: .omitted, time: .shortened))
                            .font(.nudgeDisplay(44))
                            .foregroundStyle(Theme.ink)

                        HStack(spacing: 8) {
                            presetChip(hour: 20, label: "8 PM")
                            presetChip(hour: 21, label: "9 PM")
                            presetChip(hour: 22, label: "10 PM")
                            Button {
                                isCustomTime = true
                            } label: {
                                Text("Custom")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(isCustomTime ? Theme.accent : Theme.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .overlay(Capsule().stroke(isCustomTime ? Theme.accent : Theme.line, lineWidth: isCustomTime ? 2 : 1))
                            }
                        }

                        if isCustomTime {
                            DatePicker("", selection: $reviewTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .onChange(of: reviewTime) { _, newValue in save { $0.nightlyReviewTime = newValue } }
                        }

                        Text("Only fires when something needs sorting.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "LONG-HORIZON LEAD TIMES")
                    GroupedCard {
                        StepperRow(title: "First nudge", value: $leadTimeFirstDays, suffix: "d") { newValue in
                            save { $0.leadTimeFirstDays = newValue }
                        }
                        SettingsRowDivider()
                        StepperRow(title: "Second nudge", value: $leadTimeSecondDays, suffix: "d") { newValue in
                            save { $0.leadTimeSecondDays = newValue }
                        }
                        SettingsRowDivider()
                        ToggleRow(title: "Due-date check-in", isOn: $dueDateCheckInEnabled)
                            .onChange(of: dueDateCheckInEnabled) { _, newValue in save { $0.dueDateCheckInEnabled = newValue } }
                    }

                    if let d1 = Calendar.current.date(byAdding: .day, value: -leadTimeFirstDays, to: previewDueDate),
                       let d2 = Calendar.current.date(byAdding: .day, value: -leadTimeSecondDays, to: previewDueDate) {
                        Text("Preview for a \(previewDueDate.formatted(date: .abbreviated, time: .omitted)) due date: \(d1.formatted(date: .abbreviated, time: .omitted)), \(d2.formatted(date: .abbreviated, time: .omitted)), \(previewDueDate.formatted(date: .abbreviated, time: .omitted)).")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "QUIET HOURS")
                    GroupedCard {
                        ToggleRow(title: "Hold nudges overnight", isOn: $quietHoursEnabled)
                            .onChange(of: quietHoursEnabled) { _, newValue in save { $0.quietHoursEnabled = newValue } }
                        SettingsRowDivider()
                        HStack {
                            Text("From \(quietHoursStart.formatted(date: .omitted, time: .shortened)) to \(quietHoursEnd.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.bg)
        .navigationBarHidden(true)
        .onAppear(perform: load)
    }

    private var previewDueDate: Date {
        Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    }

    private func presetChip(hour: Int, label: String) -> some View {
        let isSelected = !isCustomTime && Calendar.current.component(.hour, from: reviewTime) == hour
        return Button {
            isCustomTime = false
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = hour
            components.minute = 0
            if let date = Calendar.current.date(from: components) {
                reviewTime = date
                save { $0.nightlyReviewTime = date }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.accent : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(Capsule().stroke(isSelected ? Theme.accent : Theme.line, lineWidth: isSelected ? 2 : 1))
        }
    }

    private func load() {
        guard let settings = try? settingsRepository.fetchSettings() else { return }
        reviewTime = settings.nightlyReviewTime
        leadTimeFirstDays = settings.leadTimeFirstDays
        leadTimeSecondDays = settings.leadTimeSecondDays
        dueDateCheckInEnabled = settings.dueDateCheckInEnabled
        quietHoursEnabled = settings.quietHoursEnabled
        quietHoursStart = settings.quietHoursStart
        quietHoursEnd = settings.quietHoursEnd
        let hour = Calendar.current.component(.hour, from: reviewTime)
        isCustomTime = ![20, 21, 22].contains(hour)
    }

    private func save(_ mutate: (AppSettings) -> Void) {
        try? settingsRepository.update(mutate)
    }
}

private struct StepperRow: View {
    let title: String
    @Binding var value: Int
    let suffix: String
    let onChange: (Int) -> Void

    var body: some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer()
            Button { adjust(-1) } label: { circleLabel("−") }
            Text("\(value) \(suffix)").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink).frame(minWidth: 40)
            Button { adjust(1) } label: { circleLabel("+") }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func adjust(_ delta: Int) {
        value = max(1, min(90, value + delta))
        onChange(value)
    }

    private func circleLabel(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(width: 32, height: 32)
            .background(Theme.surfaceAlt)
            .clipShape(Circle())
    }
}
