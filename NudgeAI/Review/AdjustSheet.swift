import SwiftUI

/// Manual sort editor, opened from any review card. Reuses the shared card
/// components; save rules live in `AdjustDraft`.
struct AdjustSheet: View {
    let item: ReminderItem
    let onSave: (AdjustDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AdjustDraft
    @State private var isEditingCustomMonths = false

    init(item: ReminderItem, onSave: @escaping (AdjustDraft) -> Void) {
        self.item = item
        self.onSave = onSave
        let interval: RecurringInterval = {
            switch item.recurringInterval {
            case .some(.annual): return .annual
            case .some(.custom): return .custom
            default: return .sixMonth
            }
        }()
        _draft = State(initialValue: AdjustDraft(
            bucket: item.bucket,
            urgency: item.urgency,
            hasDeadline: item.deadline != nil,
            deadline: item.deadline ?? (Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()),
            interval: interval,
            customMonths: item.customIntervalMonths
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Adjust")
                    .font(.nudgeDisplay(34))
                    .foregroundStyle(Theme.ink)
                Text(item.rawText)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)

                SectionEyebrow(text: "TYPE")
                option("Quick task", "Do it soon, no date needed", draft.bucket == .quickTask) { draft.bucket = .quickTask }
                option("Scheduled task", "Has a date it's due", draft.bucket == .scheduledTask) { draft.bucket = .scheduledTask }
                option("Long-horizon", "Comes back every so often", draft.bucket == .longHorizon) { draft.bucket = .longHorizon }

                SectionEyebrow(text: "URGENCY")
                option("Low", "", draft.urgency == .low) { draft.urgency = .low }
                option("Medium", "", draft.urgency == .medium) { draft.urgency = .medium }
                option("High", "", draft.urgency == .high) { draft.urgency = .high }

                SectionEyebrow(text: "DEADLINE")
                GroupedCard {
                    ToggleRow(title: "Has a deadline", isOn: $draft.hasDeadline)
                    if draft.hasDeadline {
                        SettingsRowDivider()
                        DatePicker("Due", selection: $draft.deadline, displayedComponents: .date)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                }

                if draft.bucket == .scheduledTask && !draft.hasDeadline {
                    Text("A scheduled task needs a deadline.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }

                if draft.bucket == .longHorizon {
                    SectionEyebrow(text: "REPEATS")
                    option("Every six months", "", draft.interval == .sixMonth) { draft.interval = .sixMonth }
                    option("Every year", "", draft.interval == .annual) { draft.interval = .annual }
                    option(
                        "Custom",
                        draft.customMonths.map { "Every \($0) month\($0 == 1 ? "" : "s")" } ?? "Choose how many months",
                        draft.interval == .custom
                    ) {
                        draft.interval = .custom
                        isEditingCustomMonths = true
                    }
                    if !draft.hasDeadline {
                        Text("With no deadline, the first nudge is set from the repeat interval.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                }

                Button {
                    onSave(draft)
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                .disabled(!draft.isValid)
                .opacity(draft.isValid ? 1 : 0.4)

                PlainButton(label: "Cancel") { dismiss() }
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.bg)
        .sheet(isPresented: $isEditingCustomMonths) {
            CustomIntervalStepper { months in
                draft.customMonths = months
                isEditingCustomMonths = false
            }
            .presentationDetents([.medium])
        }
    }

    private func option(_ title: String, _ subtitle: String, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        RadioOptionCard(title: title, subtitle: subtitle, isSelected: selected, action: action)
    }
}
