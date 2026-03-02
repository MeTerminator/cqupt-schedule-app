import SwiftUI


struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(25)
            .padding(.top, 15)
    }
}