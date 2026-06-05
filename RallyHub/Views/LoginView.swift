import SwiftUI

struct LoginView: View {
    @Bindable private var auth = AuthService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var isLoginEnabled: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            RallyAuthBackgroundView {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack {
                            Spacer(minLength: UIScreen.main.bounds.height * 0.58)

                            Color.clear
                                .frame(height: 1)
                                .id("formAnchor")

                            VStack(spacing: 18) {
                                authField(icon: "envelope") {
                                    TextField("メールアドレス", text: $email)
                                        .foregroundColor(.black)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                }

                                authField(icon: "lock") {
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
                                    Task { await login() }
                                } label: {
                                    authPrimaryButtonLabel(
                                        title: isLoading ? "ログイン中..." : "ログイン",
                                        systemImage: "arrow.right.circle.fill",
                                        isLoading: isLoading,
                                        isEnabled: isLoginEnabled
                                    )
                                }
                                .disabled(!isLoginEnabled)

                                NavigationLink {
                                    SignUpView()
                                } label: {
                                    Text("アカウントを作成する 〉")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding(.top, 10)
                            }
                            .padding(.horizontal, 28)

                            Spacer()
                                .frame(height: 240)
                        }
                    }
                    .onChange(of: email) { _, _ in
                        scrollIfNeeded(proxy: proxy)
                    }
                    .onChange(of: password) { _, _ in
                        scrollIfNeeded(proxy: proxy)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func scrollIfNeeded(proxy: ScrollViewProxy) {
        guard !email.isEmpty, !password.isEmpty else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo("formAnchor", anchor: .top)
            }
        }
    }

    private func login() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            try await auth.login(email: email, password: password)
        } catch {
            errorMessage = AuthService.authErrorMessage(for: error, fallback: "ログインに失敗しました")
        }
    }
}
