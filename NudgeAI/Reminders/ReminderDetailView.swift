import SwiftUI
import SwiftData

/// Matches Figma node 8:148.
struct ReminderDetailView: View {
    let itemId: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var item: ReminderItem?

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(title: "", trailing: "Edit", onBack: { dismiss() }, onTrailingTap: {})

                    Text(item.rawText)
                        .font(.nudgeDisplay(40))
                        .foregroundStyle(Theme.ink)

                    HStack(spacing: 8) {
                        StatusChip(label: intervalLabel, style: .warn)
                        StatusChip(label: "Added \(item.source == .siri ? "via Siri" : "in app") · \(item.createdAt.formatted(date: .abbreviated, time: .omitted))", style: .neutral)
                    }

                    if let deadline = item.deadline {
                        SectionEyebrow(text: "NUDGE SCHEDULE")
                        NudgeTrackTimeline(deadline: deadline)
                    }

                    if let lastCompletedAt = item.lastCompletedAt {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark").foregroundStyle(Theme.success)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last completed \(lastCompletedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                Text("Next cycle was scheduled automatically.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(16)
                        .background(Theme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
                    }

                    Spacer(minLength: 40)

                    PlainButton(label: "Mark done early") {}
                    Button("Delete reminder") {}
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.warn)
                        .frame(maxWidth: .infinity)
                }
                .padding(Theme.Spacing.screenMargin)
            } else {
                ProgressView()
            }
        }
        .background(Theme.bg)
        .navigationBarHidden(true)
        .onAppear {
            item = try? SwiftDataReminderRepository(modelContext: modelContext).fetchItem(id: itemId)
        }
    }

    private var intervalLabel: String {
        guard let item else { return "" }
        switch item.recurringInterval {
        case .sixMonth: return "Every 6 months"
        case .annual: return "Yearly"
        case .custom: return item.customIntervalMonths.map { "Every \($0) months" } ?? "Custom"
        default: return ""
        }
    }
}

struct NudgeTrackTimeline: View {
    let deadline: Date

    private var stages: NudgeSchedulingLogic.ScheduleStages {
        NudgeSchedulingLogic.computeStages(deadline: deadline)
    }

    var body: some View {
        GroupedCard {
            TimelineStageRow(title: "15 days before", date: stages.leadNudgeAt, description: "A gentle heads-up", status: "Scheduled", isFirst: true)
            SettingsRowDivider()
            TimelineStageRow(title: "5 days before", date: stages.secondNudgeAt, description: "A firmer reminder", status: "Scheduled", isFirst: false)
            SettingsRowDivider()
            TimelineStageRow(title: "Due date", date: stages.dueDateCheckInAt, description: "Asks: Done or Not yet", status: "Scheduled", isFirst: false)
        }
    }
}

private struct TimelineStageRow: View {
    let title: String
    let date: Date
    let description: String
    let status: String
    let isFirst: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isFirst ? Theme.accent : Theme.line)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                if !isFirst {
                    Rectangle().fill(Theme.line).frame(width: 1).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                Text("\(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(description)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            StatusChip(label: status, style: .neutral)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
