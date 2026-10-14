import SwiftUI

struct CustomIntervalStepper: View {
    @State private var months: Int = 3
    let onConfirm: (Int) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Repeat every how many months?")
                .font(.headline)
            Stepper("\(months) month\(months == 1 ? "" : "s")", value: $months, in: 1...60)
            Button("Confirm") { onConfirm(months) }
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
}
