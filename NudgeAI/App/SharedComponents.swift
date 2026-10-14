import SwiftUI

/// Back-chevron button used on pushed screens (Settings sub-screens, Reminder detail).
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Theme.surface)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                .overlay(Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink))
        }
    }
}

/// Serif screen title paired with a back button — Settings, sub-screens, Reminder detail.
struct ScreenHeader: View {
    let title: String
    var trailing: String? = nil
    var onBack: (() -> Void)? = nil
    var onTrailingTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            if let onBack {
                BackButton(action: onBack)
            }
            Text(title)
                .font(.nudgeDisplay(34))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let trailing {
                Button(action: { onTrailingTap?() }) {
                    Text(trailing)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

/// Back button + segmented progress bar + "N of total" — onboarding steps 2+.
struct OnboardingNavHeader: View {
    let step: Int
    let total: Int
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BackButton(action: onBack)
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= step ? Theme.accent : Theme.line)
                        .frame(height: 4)
                }
            }
            Text("\(step) of \(total)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
    }
}

/// Eyebrow section label ("CAPTURE", "NUDGING SOON", etc.)
struct SectionEyebrow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.muted)
    }
}

/// Rounded card container grouping settings-style rows with 1px dividers.
struct GroupedCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.list).stroke(Theme.line, lineWidth: 1))
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Divider().background(Theme.line).padding(.leading, 16)
    }
}

/// A tappable row with a title, optional trailing value, and chevron.
struct DisclosureRow: View {
    let title: String
    var value: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

/// A row with a title and a toggle.
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(Theme.success)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// A selectable radio-style option card (model picker, transcription policy).
struct RadioOptionCard: View {
    let title: String
    let subtitle: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .stroke(isSelected ? Theme.accent : Theme.line, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle().fill(Theme.accent).frame(width: 10, height: 10).opacity(isSelected ? 1 : 0)
                    )
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                        if let badge {
                            Text(badge).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent)
                        }
                    }
                    Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            .padding(16)
            .background(isSelected ? Theme.accentSoft : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.list)
                    .stroke(isSelected ? Theme.accent : Theme.line, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

/// A vertically-centered empty state (icon + title + optional subtitle) —
/// fills remaining space in a ScrollView/VStack instead of leaving the
/// message stranded at the top with dead space below it.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(Theme.muted.opacity(0.6))
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.muted)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 60)
    }
}

/// A full-width secondary/plain button (e.g. "Mark done early", "Test a capture").
struct PlainButton: View {
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDestructive ? Theme.warn : Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.line, lineWidth: 1))
        }
    }
}
