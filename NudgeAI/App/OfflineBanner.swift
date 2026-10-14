import SwiftUI

/// Matches Figma node 7:200 ("Today — Claude unreachable").
struct OfflineBanner: View {
    var onRetry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Theme.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text("Can't reach Claude")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.warn)
                Text("Your nudges are safe. I'll sort them when you're back online.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(16)
        .background(Theme.warnSoft)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list))
    }
}
