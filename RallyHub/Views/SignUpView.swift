import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var auth = AuthService.shared

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var isEnabled: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        RallyAuthBackgroundView {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer()
                        .frame(height: 120)

                    VStack(spacing: 16) {
                        authField(icon: "person", fieldBackgroundOpacity: 0.84) {
                            TextField("表示名", text: $name)
                                .foregroundColor(.black)
                        }

                        authField(icon: "envelope", fieldBackgroundOpacity: 0.84) {
                            TextField("メールアドレス", text: $email)
                                .foregroundColor(.black)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }

                        authField(icon: "lock", fieldBackgroundOpacity: 0.84) {
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("パスワード", text: $password)
                                            .foregroundColor(.black)
                                    } else {
                                        SecureField("パスワード", text: $password)
                                            .foregroundColor(.black)
                                    }
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.black)
                                }
                            }
                        }

                        if !errorMessage.isEmpty {
                            authErrorBanner(errorMessage)
                        }

                        Button {
                            hideKeyboard()
                            Task { await signUp() }
                        } label: {
                            authPrimaryButtonLabel(
                                title: isLoading ? "登録中..." : "アカウント作成",
                                systemImage: "person.crop.circle.badge.plus",
                                isLoading: isLoading,
                                isEnabled: isEnabled
                            )
                        }
                        .disabled(!isEnabled)
                    }
                    .padding(.horizontal, 28)

                    Spacer()
                        .frame(height: 120)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func signUp() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            try await auth.signUp(name: name, email: email, password: password)
            dismiss()
        } catch {
            errorMessage = AuthService.authErrorMessage(for: error, fallback: "アカウント作成に失敗しました")
        }
    }
}
