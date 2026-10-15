import SwiftUI

/// Chat-thread content for the follow-up Q&A and confirmation, rendered
/// inside CaptureSheet's scroll view — matches Figma node 7:93.
struct FollowUpChatView: View {
    @ObservedObject var viewModel: FollowUpViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            if let question = viewModel.question {
                AssistantBubble(text: question.question)

                if !viewModel.isComplete {
                    FlowChips(options: question.options) { option in
                        Task { await viewModel.select(option) }
                    }
                    Button("Custom\u{2026}") { viewModel.promptCustomInterval() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            if viewModel.isComplete {
                if viewModel.isSavedUnsorted || viewModel.computedBucket == nil {
                    AssistantBubble(text: "Got it. Saved. You'll sort it at review.")
                } else {
                    AssistantBubble(text: confirmationText)
                    SuccessBlock(bucket: viewModel.computedBucket, deadline: viewModel.computedDeadline)
                }
            }
        }
        .sheet(isPresented: $viewModel.isPromptingCustomInterval) {
            CustomIntervalStepper { months in
                Task { await viewModel.confirmCustomInterval(months: months) }
            }
        }
    }

    private var confirmationText: String {
        guard let deadline = viewModel.computedDeadline else {
            return "Got it. No deadline — I'll keep it simple."
        }
        return "Got it. I'll nudge you before \(deadline.formatted(date: .abbreviated, time: .omitted))."
    }
}

private struct FlowChips: View {
    let options: [QuickReplyOption]
    let onTap: (QuickReplyOption) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button(option.label) { onTap(option) }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.surface)
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct SuccessBlock: View {
    let bucket: ReminderBucket?
    let deadline: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark").foregroundStyle(Theme.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("Saved as \(bucketLabel)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.success)
                if let deadline {
                    Text("Next due \(deadline.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.successSoft)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bucketLabel: String {
        switch bucket {
        case .longHorizon: return "long-horizon"
        case .scheduledTask: return "scheduled task"
        case .quickTask, .none: return "quick task"
        }
    }
}
