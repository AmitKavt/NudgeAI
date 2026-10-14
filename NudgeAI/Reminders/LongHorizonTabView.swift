import SwiftUI

/// Matches Figma node 8:74.
struct LongHorizonTabView: View {
    @ObservedObject var viewModel: LongHorizonViewModel
    @State private var selectedItemId: UUID?

    private var isEmpty: Bool { viewModel.nudgingSoon.isEmpty && viewModel.later.isEmpty }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Long-horizon")
                                .font(.nudgeDisplay(42))
                                .foregroundStyle(Theme.ink)
                            Text("Resting until their window opens.")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.muted)
                        }

                        if !viewModel.nudgingSoon.isEmpty {
                            SectionEyebrow(text: "NUDGING SOON")
                            VStack(spacing: 12) {
                                ForEach(viewModel.nudgingSoon) { item in
                                    Button { selectedItemId = item.id } label: {
                                        NudgingSoonCard(item: item)
                                    }
                                }
                            }
                        }

                        if !viewModel.later.isEmpty {
                            SectionEyebrow(text: "LATER")
                            GroupedCard {
                                ForEach(Array(viewModel.later.enumerated()), id: \.element.id) { index, item in
                                    DisclosureRow(title: item.rawText, value: laterSubtitle(item)) {
                                        selectedItemId = item.id
                                    }
                                    if index < viewModel.later.count - 1 {
                                        SettingsRowDivider()
                                    }
                                }
                            }
                        }

                        if isEmpty {
                            Spacer(minLength: 0)
                            EmptyStateView(
                                systemImage: "calendar",
                                title: "No long-horizon nudges yet",
                                subtitle: "Reminders you tag as recurring (every 6 months, yearly) show up here."
                            )
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.top, 6)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(Theme.bg)
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedItemId) { itemId in
                ReminderDetailView(itemId: itemId)
            }
        }
        .onAppear { viewModel.load() }
    }

    private func laterSubtitle(_ item: ReminderItem) -> String {
        guard let deadline = item.deadline else { return intervalLabel(item) }
        return "\(intervalLabel(item)) · due \(deadline.formatted(date: .abbreviated, time: .omitted))"
    }

    private func intervalLabel(_ item: ReminderItem) -> String {
        switch item.recurringInterval {
        case .sixMonth: return "Every 6 months"
        case .annual: return "Yearly"
        case .custom: return item.customIntervalMonths.map { "Every \($0) months" } ?? "Custom"
        default: return ""
        }
    }
}

private struct NudgingSoonCard: View {
    let item: ReminderItem

    private var stages: NudgeSchedulingLogic.ScheduleStages? {
        item.deadline.map { NudgeSchedulingLogic.computeStages(deadline: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.rawText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                StatusChip(label: intervalLabel, style: .warn)
            }

            if let deadline = item.deadline {
                Text("Due \(deadline.formatted(date: .complete, time: .omitted))\(nextNudgeCaption)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }

            if let stages {
                let nextDate = NudgeSchedulingLogic.nextNudgeAt(from: stages)
                HStack(spacing: 0) {
                    TimelineDot(date: stages.leadNudgeAt, label: "days before", isNext: stages.leadNudgeAt == nextDate)
                        .frame(maxWidth: .infinity)
                    TimelineLine()
                    TimelineDot(date: stages.secondNudgeAt, label: "days before", isNext: stages.secondNudgeAt == nextDate)
                        .frame(maxWidth: .infinity)
                    TimelineLine()
                    TimelineDot(date: stages.dueDateCheckInAt, label: "Due date", isNext: stages.dueDateCheckInAt == nextDate)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.accent, lineWidth: 2))
    }

    private var intervalLabel: String {
        switch item.recurringInterval {
        case .sixMonth: return "Every 6 months"
        case .annual: return "Yearly"
        case .custom: return item.customIntervalMonths.map { "Every \($0) months" } ?? "Custom"
        default: return ""
        }
    }

    private var nextNudgeCaption: String {
        guard let stages, let nextDate = NudgeSchedulingLogic.nextNudgeAt(from: stages) else { return "" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
        if days <= 0 { return " · first nudge today" }
        if days < 14 { return " · first nudge in \(days) day\(days == 1 ? "" : "s")" }
        let weeks = days / 7
        return " · first nudge in \(weeks) week\(weeks == 1 ? "" : "s")"
    }
}

private struct TimelineDot: View {
    let date: Date
    let label: String
    let isNext: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(isNext ? Theme.accent : Theme.line)
                .frame(width: 10, height: 10)
            Text(date.formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
    }
}

private struct TimelineLine: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1).padding(.bottom, 34)
    }
}
