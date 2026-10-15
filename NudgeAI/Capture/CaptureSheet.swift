import SwiftUI

/// Matches Figma node 7:93 ("Capture — follow-up question"): a single chat-thread
/// sheet — type/speak the nudge in the bottom bar, the follow-up and the
/// confirmation both render as chat bubbles in the same scroll.
struct CaptureSheet: View {
    @ObservedObject var viewModel: CaptureViewModel
    let client: ClassificationClient?
    let reminderRepository: ReminderRepository
    let settingsRepository: SettingsRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var followUpBox = FollowUpViewModelBox()

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.line)
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New nudge")
                        .font(.nudgeDisplay(34))
                        .foregroundStyle(Theme.ink)
                    Text(client == nil
                         ? "Saved as you capture it. You'll sort it at review."
                         : "In here I can ask a quick question, so this skips tonight's review.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Theme.surfaceAlt)
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink))
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, Theme.Spacing.screenMargin)

            ScrollView {
                VStack(alignment: .trailing, spacing: 16) {
                    if let item = viewModel.capturedItem {
                        UserBubble(text: item.rawText)

                        FollowUpChatContent(
                            box: followUpBox,
                            item: item,
                            client: client,
                            reminderRepository: reminderRepository,
                            settingsRepository: settingsRepository
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.top, 20)
            }

            InputBar(viewModel: viewModel)
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.bottom, 12)
        }
        .background(Theme.bg)
    }
}

/// Holds the FollowUpViewModel so it's created exactly once per captured item.
private final class FollowUpViewModelBox: ObservableObject {
    @Published var viewModel: FollowUpViewModel?
}

private struct FollowUpChatContent: View {
    @ObservedObject var box: FollowUpViewModelBox
    let item: ReminderItem
    let client: ClassificationClient?
    let reminderRepository: ReminderRepository
    let settingsRepository: SettingsRepository

    var body: some View {
        Group {
            if let vm = box.viewModel {
                FollowUpChatView(viewModel: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            if box.viewModel == nil {
                let vm = FollowUpViewModel(
                    item: item,
                    client: client,
                    reminderRepository: reminderRepository,
                    settingsRepository: settingsRepository
                )
                box.viewModel = vm
                await vm.start()
            }
        }
    }
}

private struct InputBar: View {
    @ObservedObject var viewModel: CaptureViewModel

    var body: some View {
        HStack(spacing: 10) {
            TextField("Type or tap the mic", text: $viewModel.draftText)
                .font(.system(size: 16))
            Button {
                Task {
                    if viewModel.isRecording {
                        await viewModel.stopVoiceInput()
                    } else {
                        await viewModel.startVoiceInput()
                    }
                }
            } label: {
                Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                    .foregroundStyle(viewModel.isRecording ? Theme.warn : Theme.ink)
                    .frame(width: 32, height: 32)
                    .background(Theme.surfaceAlt)
                    .clipShape(Circle())
            }
            Button {
                viewModel.submitDraft()
            } label: {
                Image(systemName: "arrow.up")
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 36, height: 36)
                    .background(Theme.accent)
                    .clipShape(Circle())
            }
            .disabled(viewModel.capturedItem != nil || viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

struct UserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct AssistantBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.night)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "sparkle").font(.system(size: 13)).foregroundStyle(Theme.accentNight))
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
