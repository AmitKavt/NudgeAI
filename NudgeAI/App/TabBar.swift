import SwiftUI

enum AppTab: Hashable {
    case today
    case review
    case horizon
    case you
}

struct TabBar: View {
    @Binding var selection: AppTab
    let onCapture: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(systemImage: "sun.max", label: "Today", isActive: selection == .today) {
                selection = .today
            }
            TabBarItem(systemImage: "checkmark.circle", label: "Review", isActive: selection == .review) {
                selection = .review
            }

            Button(action: onCapture) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 6)
            }
            .offset(y: -4)

            TabBarItem(systemImage: "calendar", label: "Horizon", isActive: selection == .horizon) {
                selection = .horizon
            }
            TabBarItem(systemImage: "person", label: "You", isActive: selection == .you) {
                selection = .you
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.1), radius: 12, y: 8)
    }
}

private struct TabBarItem: View {
    let systemImage: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
            }
            .foregroundStyle(isActive ? Theme.accent : Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
    }
}
