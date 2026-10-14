import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    @StateObject private var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    init(
        apiKeyStore: APIKeyStore,
        settingsRepository: SettingsRepository,
        startingStep: OnboardingStep = .welcome,
        onComplete: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(
            apiKeyStore: apiKeyStore,
            settingsRepository: settingsRepository,
            startingStep: startingStep
        ))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            switch viewModel.step {
            case .welcome:
                WelcomeStepView { viewModel.advance() }
            case .connectClaude:
                ConnectClaudeStepView(viewModel: viewModel)
            case .teachSiri:
                TeachSiriStepView(onBack: viewModel.goBack, onNext: viewModel.advance)
            case .permissions:
                PermissionsStepView(onBack: viewModel.goBack) {
                    Task {
                        await viewModel.requestPermissionsAndComplete()
                        onComplete()
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.bg)
    }
}

/// Matches Figma node 6:2.
private struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Circle()
                    .fill(Theme.accentSoft)
                    .frame(width: 180, height: 180)
                    .overlay(Image(systemName: "mic.fill").font(.system(size: 56)).foregroundStyle(Theme.accent))

                VStack(spacing: 12) {
                    Text("Capture anything in two seconds.")
                        .font(.nudgeDisplay(40))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text("No categories, no deadlines, no decisions. Say it now. Claude sorts it out tonight.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("Get started")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                Text("Your notes and key stay on this iPhone.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 44)
    }
}

/// Matches Figma node 6:25 ("1 of 3").
private struct ConnectClaudeStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingNavHeader(step: 1, total: 3, onBack: viewModel.goBack)

            Text("Connect Claude")
                .font(.nudgeDisplay(40))
                .foregroundStyle(Theme.ink)
            Text("Nudge uses your own Anthropic API key to sort what you capture. It lives in the iPhone Keychain.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)

            VStack(alignment: .leading, spacing: 6) {
                Text("API key")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                HStack {
                    SecureField("sk-ant-...", text: $viewModel.apiKeyInput)
                        .font(.system(size: 16))
                    Button("Paste") {
                        if let pasted = UIPasteboard.general.string {
                            viewModel.apiKeyInput = pasted
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accentSoft)
                    .clipShape(Capsule())
                }
                .padding(16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.list).stroke(Theme.accent, lineWidth: 2))
            }

            if let error = viewModel.keyValidationError {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.warn)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill").foregroundStyle(Theme.muted)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private by design").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("Calls go straight from your phone to Claude. No server in between. Typical cost with Claude Haiku is well under $1 a month.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(16)
            .background(Theme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))

            Spacer()

            VStack(spacing: 12) {
                Button(action: viewModel.saveAPIKey) {
                    Text("Verify and continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                Button("I'll get a key first") { viewModel.advance() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

/// Matches Figma node 6:61 ("2 of 3").
private struct TeachSiriStepView: View {
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingNavHeader(step: 2, total: 3, onBack: onBack)

            Text("Teach Siri your phrase")
                .font(.nudgeDisplay(36))
                .foregroundStyle(Theme.ink)
            Text("Works with the phone locked, in your pocket, or in the car.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)

            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "mic.fill").font(.system(size: 18)).foregroundStyle(Theme.accentNight)
                Text("\u{201C}Hey Siri, nudge me\u{201D}")
                    .font(.nudgeDisplay(32))
                    .foregroundStyle(Theme.onNight)
                Text("Then just say what's on your mind.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.onNightMuted)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.night)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

            VStack(alignment: .leading, spacing: 18) {
                OnboardingStepItem(number: 1, title: "Say your thought", subtitle: "No questions. Nudge saves it exactly as you said it.")
                OnboardingStepItem(number: 2, title: "Keep going with your day", subtitle: "Capture finishes in about two seconds.")
                OnboardingStepItem(number: 3, title: "Tonight, Claude sorts it", subtitle: "You approve in one tap.")
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("Add to Siri")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                Button("Choose a different phrase") {}
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

private struct OnboardingStepItem: View {
    let number: Int
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Theme.accentSoft)
                .frame(width: 28, height: 28)
                .overlay(Text("\(number)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Matches Figma node 6:109 ("3 of 3").
private struct PermissionsStepView: View {
    let onBack: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingNavHeader(step: 3, total: 3, onBack: onBack)

            Text("Three quick permissions")
                .font(.nudgeDisplay(36))
                .foregroundStyle(Theme.ink)
            Text("Each one only does what it says.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)

            VStack(spacing: 12) {
                PermissionRow(icon: "mic.fill", title: "Microphone", subtitle: "Hear you when you say your phrase.")
                PermissionRow(icon: "bubble.left.fill", title: "Speech recognition", subtitle: "Turn your voice into text on this device.")
                PermissionRow(icon: "bell.fill", title: "Notifications", subtitle: "Nightly review and long-horizon nudges.")
            }

            Spacer()

            Button(action: onFinish) {
                Text("Finish setup")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.accentSoft)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Theme.accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.list).stroke(Theme.line, lineWidth: 1))
    }
}
