import SwiftUI

/// Matches Figma node 9:334.
struct CaptureSettingsView: View {
    let settingsRepository: SettingsRepository
    @Environment(\.dismiss) private var dismiss

    @State private var siriPhrase = ""
    @State private var confirmWithHaptic = true
    @State private var confirmWithSpokenWord = false
    @State private var language = ""
    @State private var unsureTranscriptionPolicy: AmbiguousTranscriptionPolicy = .saveAndFlag

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Capture", onBack: { dismiss() })

                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR SIRI PHRASE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accentNight)
                    Text("\u{201C}\(siriPhrase)\u{201D}")
                        .font(.nudgeDisplay(30))
                        .foregroundStyle(Theme.onNight)
                    Button("Change phrase") {}
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                .padding(Theme.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.night)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "FEEDBACK")
                    GroupedCard {
                        ToggleRow(title: "Haptic when saved", isOn: $confirmWithHaptic)
                            .onChange(of: confirmWithHaptic) { _, newValue in save { $0.confirmWithHaptic = newValue } }
                        SettingsRowDivider()
                        ToggleRow(title: "Say \u{201C}Saved\u{201D} out loud", isOn: $confirmWithSpokenWord)
                            .onChange(of: confirmWithSpokenWord) { _, newValue in save { $0.confirmWithSpokenWord = newValue } }
                        SettingsRowDivider()
                        DisclosureRow(title: "Language", value: language) {}
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionEyebrow(text: "WHEN I'M NOT SURE WHAT I HEARD")
                    VStack(spacing: 12) {
                        RadioOptionCard(
                            title: "Save it and flag it",
                            subtitle: "Keeps your raw words and asks at tonight's review.",
                            isSelected: unsureTranscriptionPolicy == .saveAndFlag
                        ) { setPolicy(.saveAndFlag) }

                        RadioOptionCard(
                            title: "Don't save",
                            subtitle: "Discard anything below the confidence threshold.",
                            isSelected: unsureTranscriptionPolicy == .dontSave
                        ) { setPolicy(.dontSave) }
                    }
                }

                PlainButton(label: "Test a capture") {}
            }
            .padding(Theme.Spacing.screenMargin)
        }
        .background(Theme.bg)
        .navigationBarHidden(true)
        .onAppear(perform: load)
    }

    private func load() {
        guard let settings = try? settingsRepository.fetchSettings() else { return }
        siriPhrase = settings.siriPhrase
        confirmWithHaptic = settings.confirmWithHaptic
        confirmWithSpokenWord = settings.confirmWithSpokenWord
        language = settings.language
        unsureTranscriptionPolicy = settings.unsureTranscriptionPolicy
    }

    private func setPolicy(_ policy: AmbiguousTranscriptionPolicy) {
        unsureTranscriptionPolicy = policy
        save { $0.unsureTranscriptionPolicy = policy }
    }

    private func save(_ mutate: (AppSettings) -> Void) {
        try? settingsRepository.update(mutate)
    }
}
