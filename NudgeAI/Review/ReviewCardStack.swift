import SwiftUI

struct ReviewCardStack: View {
    @ObservedObject var viewModel: ReviewViewModel
    @ObservedObject private var unreachableState = ClaudeUnreachableState.shared

    var body: some View {
        VStack(spacing: 18) {
            NavRow(remaining: viewModel.queue.count)

            if unreachableState.isUnreachable {
                Spacer()
                Text("Paused until Claude is reachable")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.warn)
                Spacer()
            } else if let topItem = viewModel.queue.first {
                ProgressSegments(total: max(viewModel.queue.count, 1), completedCount: 0)

                ReviewCard(item: topItem)
                    .gesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                if value.translation.width > 0 {
                                    viewModel.accept(topItem)
                                } else {
                                    viewModel.skip(topItem)
                                }
                            }
                    )

                Text("Swipe right to accept · left to skip")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)

                Spacer()

                Button {
                    viewModel.accept(topItem)
                } label: {
                    Text("Looks right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }

                HStack(spacing: 12) {
                    SecondaryButton(label: "Adjust") { viewModel.skip(topItem) }
                    SecondaryButton(label: "Not today") { viewModel.skip(topItem) }
                }
            } else {
                Spacer()
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "Nothing to review",
                    subtitle: "New captures that need a decision will show up here."
                )
                Spacer()
            }
        }
        .padding(.horizontal, Theme.Spacing.screenMargin)
        .padding(.bottom, 36)
        .background(Theme.bg)
        .onAppear { viewModel.loadQueue() }
        .sheet(isPresented: Binding(
            get: { viewModel.itemNeedingCustomInterval != nil },
            set: { if !$0 { viewModel.itemNeedingCustomInterval = nil } }
        )) {
            CustomIntervalStepper { months in
                viewModel.confirmCustomInterval(months: months)
            }
        }
    }
}

private struct NavRow: View {
    let remaining: Int

    var body: some View {
        HStack {
            Circle()
                .stroke(Theme.line, lineWidth: 1)
                .background(Circle().fill(Theme.surface))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(Theme.ink))
            Spacer()
            Text("Tonight's review")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(remaining > 0 ? "1 of \(remaining)" : "")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.top, 6)
    }
}

private struct ProgressSegments: View {
    let total: Int
    let completedCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < completedCount ? Theme.accent : Theme.line)
                    .frame(height: 4)
            }
        }
    }
}

private struct SecondaryButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.line, lineWidth: 1))
        }
    }
}

private struct ReviewCard: View {
    let item: ReminderItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOU SAID")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)

            Text(item.rawText)
                .font(.nudgeDisplay(32))
                .foregroundStyle(Theme.ink)

            Text("Captured by \(item.source == .siri ? "Siri" : "in-app") · \(item.createdAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)

            Divider().background(Theme.line)

            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text("CLAUDE SUGGESTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            if let bucket = item.bucket {
                InfoRow(label: "Type", value: bucketLabel(bucket))
            }

            if let urgency = item.urgency {
                HStack {
                    Text("Urgency").font(.system(size: 15)).foregroundStyle(Theme.muted)
                    Spacer()
                    StatusChip(label: urgencyLabel(urgency), isWarn: urgency != .low)
                }
            }

            if let deadline = item.deadline {
                InfoRow(label: "Deadline", value: deadline.formatted(date: .abbreviated, time: .omitted))
            }

            if let confidence = item.confidence {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Confidence").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text("\(Int(confidence * 100))%").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Theme.surfaceAlt).frame(height: 6)
                            RoundedRectangle(cornerRadius: 3).fill(Theme.accent)
                                .frame(width: geometry.size.width * confidence, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(Theme.Spacing.cardPadding + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.line, lineWidth: 1))
    }

    private func bucketLabel(_ bucket: ReminderBucket) -> String {
        switch bucket {
        case .quickTask: return "Quick task"
        case .scheduledTask: return "Scheduled task"
        case .longHorizon: return "Long-horizon"
        }
    }

    private func urgencyLabel(_ urgency: ReminderUrgency) -> String {
        switch urgency {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
        }
    }
}
