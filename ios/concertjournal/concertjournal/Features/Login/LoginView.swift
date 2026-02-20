//
//  LoginView.swift
//  concertjournal
//
// Wird als Sheet vom Profil aus presentiert.
// Kein OnboardingManager-Binding mehr nötig –
// der User kann jederzeit mit dem X schließen.
//

import SwiftUI
import SpotifyiOS

struct LoginView: View, KeyboardReadable {

    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss

    @State private var isKeyboardVisible = false
    @State private var viewModel: AuthViewModel?

    @State private var loginType: LoginType = .login
    @State private var showPassword = false

    @State private var loginTypeAnimated: LoginType = .login
    @State private var isLoadingAnimated: Bool = false
    @State private var errorMessageAnimated: String? = nil

    @State private var passwordResetPresenting: Bool = false

    @FocusState var emailTextField: Bool
    @FocusState var passwordTextField: Bool
    @FocusState var newPasswordRepeatTextField: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.3),
                        Color.accentColor.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture { dismissKeyboard() }

                if let viewModel {
                    viewWithViewModel(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .onReceive(keyboardPublisher) { value in
                withAnimation { isKeyboardVisible = value }
            }
            .toolbar {
                // ✅ Schließen-Button – kein Zwang mehr
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .task {
                guard viewModel == nil else { return }
                viewModel = AuthViewModel(
                    supabaseClient: dependencies.supabaseClient,
                    userSessionManager: dependencies.userSessionManager
                )
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    func viewWithViewModel(viewModel: AuthViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack {
            if !isKeyboardVisible {
                Spacer()
                Text(TextKey.name.localized)
                    .font(.cjLargeTitle)
                Text(TextKey.clouds.localized)
                    .font(.cjBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
            loginContent(viewModel: viewModel)
        }
        .padding()
        .onChange(of: viewModel.isLoading) { _, newValue in
            withAnimation { isLoadingAnimated = newValue }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            withAnimation { errorMessageAnimated = newValue }
        }
        // ✅ Nach erfolgreichem Login automatisch schließen
        .onChange(of: dependencies.userSessionManager.state) { _, newState in
            if case .loggedIn = newState {
                dismiss()
            }
        }
        .sheet(isPresented: $passwordResetPresenting) {
            ForgotPasswordView(email: viewModel.email)
        }
        .overlay {
            if isLoadingAnimated { loadingOverlay() }
        }
    }

    // MARK: - Form

    @ViewBuilder
    func loginContent(viewModel: AuthViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 16) {
            Picker("", selection: $loginType) {
                ForEach(LoginType.allCases, id: \.rawValue) { type in
                    Text(type.label).tag(type).font(.cjBody)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: loginType) { _, newValue in
                withAnimation { loginTypeAnimated = newValue }
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Email", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($emailTextField)
                    .submitLabel(.next)
                    .font(.cjBody)
                    .padding()
                    .glassEffect()
                    .onSubmit { passwordTextField = true }

                // Passwort
                passwordField(viewModel: viewModel)

                // Passwort wiederholen (nur Registrierung)
                if loginTypeAnimated == .register {
                    passwordRepeatField(viewModel: viewModel)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.buttonTap()
                        passwordResetPresenting = true
                    } label: {
                        Text(TextKey.authForgotPassword.localized)
                            .font(.cjFootnote)
                            .underline()
                    }
                }
            }

            if let error = errorMessageAnimated {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.cjFootnote)
                    .transition(.opacity)
            }

            loginButtons(viewModel: viewModel)
        }
        .padding()
        .rectangleGlass()
    }

    // MARK: - Password Fields

    @ViewBuilder
    func passwordField(viewModel: AuthViewModel) -> some View {
        @Bindable var viewModel = viewModel

        ZStack {
            if showPassword {
                TextField("Passwort", text: $viewModel.password)
                    .textInputAutocapitalization(.never)
                    .focused($passwordTextField)
                    .submitLabel(loginType == .login ? .go : .next)
                    .font(.cjBody).padding().glassEffect()
                    .onSubmit {
                        if loginType == .login { Task { await viewModel.signInWithEmail() } }
                        else { newPasswordRepeatTextField = true }
                    }
            } else {
                SecureField("Passwort", text: $viewModel.password)
                    .textContentType(loginType == .login ? .password : .newPassword)
                    .focused($passwordTextField)
                    .submitLabel(loginType == .login ? .go : .next)
                    .font(.cjBody).padding().glassEffect()
                    .onSubmit {
                        if loginType == .login { Task { await viewModel.signInWithEmail() } }
                        else { newPasswordRepeatTextField = true }
                    }
            }
            HStack {
                Spacer()
                Button { withAnimation { showPassword.toggle() } } label: {
                    Image(systemName: showPassword ? "eye" : "eye.slash")
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    func passwordRepeatField(viewModel: AuthViewModel) -> some View {
        @Bindable var viewModel = viewModel

        ZStack {
            if showPassword {
                TextField("Passwort wiederholen", text: $viewModel.newPasswordRepeat)
                    .textInputAutocapitalization(.never)
                    .focused($newPasswordRepeatTextField)
                    .submitLabel(.go)
                    .font(.cjBody).padding().glassEffect()
                    .onSubmit { Task { await viewModel.signUpWithEmail() } }
            } else {
                SecureField("Passwort wiederholen", text: $viewModel.newPasswordRepeat)
                    .textContentType(.newPassword)
                    .focused($newPasswordRepeatTextField)
                    .submitLabel(.go)
                    .font(.cjBody).padding().glassEffect()
                    .onSubmit { Task { await viewModel.signUpWithEmail() } }
            }
            HStack {
                Spacer()
                Button { withAnimation { showPassword.toggle() } } label: {
                    Image(systemName: showPassword ? "eye" : "eye.slash")
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    func loginButtons(viewModel: AuthViewModel) -> some View {
        VStack(spacing: 16) {
            // Email Button
            Button {
                dismissKeyboard()
                switch loginType {
                case .login:   Task { await viewModel.signInWithEmail() }
                case .register: Task { await viewModel.signUpWithEmail() }
                }
            } label: {
                Group {
                    switch loginTypeAnimated {
                    case .login:
                        Text(TextKey.authLogin.localized)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    case .register:
                        Text(TextKey.authRegister.localized)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .font(.cjBody)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
            .buttonStyle(.glassProminent)
            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)

            Divider().padding(.vertical, 4)

            // Spotify Button
            Button { Task { await viewModel.signInWithSpotify() } } label: {
                HStack {
                    Image("Spotify")
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(height: 38)
                    Text(TextKey.loginWithSpotify.localized)
                        .font(.cjBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(6)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Loading Overlay

    @State private var showLoading: Bool = false

    @ViewBuilder
    func loadingOverlay() -> some View {
        VStack {
            Spacer()
            if showLoading {
                VStack {
                    ProgressView().padding()
                    Text(TextKey.loadingData.localized).font(.cjTitle)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .background(Color(uiColor: .systemBackground).clipShape(RoundedRectangle(cornerRadius: 25)))
                .padding()
                .transition(.move(edge: .bottom))
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.1).ignoresSafeArea())
        .transition(.opacity)
        .onAppear {
            withAnimation(.bouncy.delay(0.2)) { showLoading = true }
        }
    }

    // MARK: - Helpers

    func dismissKeyboard() {
        emailTextField = false
        passwordTextField = false
        newPasswordRepeatTextField = false
    }

    enum LoginType: String, CaseIterable {
        case login, register
        var label: String {
            switch self {
            case .login:    return "Anmelden"
            case .register: return "Registrieren"
            }
        }
    }
}

// MARK: - Keyboard Publisher

import Combine

protocol KeyboardReadable {
    var keyboardPublisher: AnyPublisher<Bool, Never> { get }
}

extension KeyboardReadable {
    var keyboardPublisher: AnyPublisher<Bool, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .map { _ in true },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in false }
        )
        .eraseToAnyPublisher()
    }
}
