import SwiftUI

/// ログイン / 新規登録画面の背景（Rally シリーズ共通）
struct RallyAuthBackgroundView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Image("login_bg")
                .resizable()
                .scaledToFill()
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .clipped()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content()
        }
    }
}

func authField<Content: View>(
    icon: String,
    fieldBackgroundOpacity: Double = 0.72,
    @ViewBuilder content: () -> Content
) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .foregroundColor(.black)
        content()
    }
    .padding()
    .background(Color.white.opacity(fieldBackgroundOpacity))
    .cornerRadius(18)
}

func authErrorBanner(_ message: String) -> some View {
    HStack(spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
        Text(message)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
        Spacer()
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .background(
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black.opacity(0.45))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.red.opacity(0.65), lineWidth: 1)
    )
}

func authPrimaryButtonLabel(
    title: String,
    systemImage: String,
    isLoading: Bool,
    isEnabled: Bool
) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                isEnabled
                ? LinearGradient(
                    colors: [Color.orange, Color.red.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                : LinearGradient(
                    colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.55)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: systemImage)
                    .font(.headline)
            }
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
    }
    .frame(height: 58)
    .shadow(color: .orange.opacity(0.35), radius: 10)
}
