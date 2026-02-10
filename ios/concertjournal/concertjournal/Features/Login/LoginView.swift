import SwiftUI
import SpotifyiOS

struct LoginView: View, KeyboardReadable {

    @Environment(\.dependencies) var dependencies
    @Bindable var manager: OnboardingManager

    @State private var isKeyboardVisible = false

    @State var viewModel: AuthViewModel?
    
    @State private var loginType: LoginType = .login
    @State private var showPassword = false
    
    @State private var loginTypeAnimated: LoginType = .login
    @State private var isLoadingAnimated: Bool = false
    @State private var errorMessageAnimated: String? = nil
    
    @State private var passwordResetPresenting: Bool = false
    
    @FocusState var emailTextField: Bool
    @FocusState var passwordTextField: Bool
    @FocusState var newPassowrdRepeatTextField: Bool

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
                .onTapGesture {
                    dismissKeyboard()
                }

                if let viewModel {
                    viewWithViewModel(viewModel: viewModel)
                } else {
                    Text("Laden fehlgeschlagen")
                }
            }
            .onReceive(keyboardPublisher, perform: { value in
                withAnimation {
                    isKeyboardVisible = value
                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            manager.resetOnboarding()
                        } label: {
                            Text("Onboarding neu starten")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .task {
                guard viewModel == nil else { return }
                print("Dependencies", dependencies)
                viewModel = AuthViewModel(supabaseClient: dependencies.supabaseClient, userSessionManager: dependencies.userSessionManager)
            }
        }
    }
    
    @ViewBuilder
    func viewWithViewModel(viewModel: AuthViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack {
            if !isKeyboardVisible {
                Spacer()
                Text("Concert Journal")
                    .font(.cjLargeTitle)

                Text("All Deine Konzerte, gespeichert an einem Ort.")
                    .font(.cjBody)
            }
            Spacer()

            loginContent(viewModel: viewModel)
        }
        .padding()
        .onChange(of: viewModel.isLoading, { _, newValue in
            withAnimation {
                isLoadingAnimated = newValue
            }
        })
        .onChange(of: viewModel.errorMessage, { _, newValue in
            withAnimation {
                errorMessageAnimated = newValue
            }
        })
        .sheet(isPresented: $passwordResetPresenting) {
            ForgotPasswordView(email: viewModel.email)
        }
        .overlay {
            if isLoadingAnimated {
                loadingOverlay()
            }
        }
    }
    
    @ViewBuilder
    func loginContent(viewModel: AuthViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 16) {
            Text("Hier geht es los")
                .font(.cjCaption)
            
            Picker("", selection: $loginType) {
                ForEach(LoginType.allCases, id: \.rawValue) { type in
                    Text(type.label)
                        .tag(type)
                        .font(.cjBody)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: loginType) { _, newValue in
                withAnimation {
                    loginTypeAnimated = newValue
                }
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
                    .onSubmit {
                        passwordTextField = true
                    }
                
                ZStack {
                    if showPassword {
                        TextField("Passwort", text: $viewModel.password)
                            .textInputAutocapitalization(.never)
                            .focused($passwordTextField)
                            .submitLabel(loginType == .login ? .go : .next)
                            .font(.cjBody)
                            .padding()
                            .glassEffect()
                            .onSubmit {
                                switch loginType {
                                case .login:
                                    Task { await viewModel.signInWithEmail() }
                                case .register:
                                    newPassowrdRepeatTextField = true
                                }
                            }
                    } else {
                        SecureField("Passwort", text: $viewModel.password)
                            .font(.cjBody)
                            .textContentType(loginType == .login ? .password : .newPassword)
                            .focused($passwordTextField)
                            .submitLabel(loginType == .login ? .go : .next)
                            .padding()
                            .glassEffect()
                            .onSubmit {
                                switch loginType {
                                case .login:
                                    Task { await viewModel.signInWithEmail() }
                                case .register:
                                    newPassowrdRepeatTextField = true
                                }
                            }
                    }
                    
                    HStack {
                        Spacer()
                        Button {
                            withAnimation {
                                showPassword.toggle()
                            }
                        } label: {
                            showPassword ? Image(systemName: "eye") : Image(systemName: "eye.slash")
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal)
                    }
                }
                
                if loginTypeAnimated == .register {
                    ZStack {
                        if showPassword {
                            TextField("Passwort wiederholen", text: $viewModel.newPasswordRepeat)
                                .textInputAutocapitalization(.never)
                                .focused($newPassowrdRepeatTextField)
                                .submitLabel(.go)
                                .font(.cjBody)
                                .padding()
                                .glassEffect()
                                .onSubmit {
                                    Task { await viewModel.signUpWithEmail() }
                                }
                        } else {
                            SecureField("Passwort wiederholen", text: $viewModel.newPasswordRepeat)
                                .font(.cjBody)
                                .textContentType(.newPassword)
                                .focused($newPassowrdRepeatTextField)
                                .submitLabel(.go)
                                .padding()
                                .glassEffect()
                                .onSubmit {
                                    Task { await viewModel.signUpWithEmail() }
                                }
                        }
                        
                        HStack {
                            Spacer()
                            Button {
                                withAnimation {
                                    showPassword.toggle()
                                }
                            } label: {
                                showPassword ? Image(systemName: "eye") : Image(systemName: "eye.slash")
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                HStack {
                    Spacer()
                    Button {
                        passwordResetPresenting = true
                    } label: {
                        Text("Passwort vergessen")
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
        .background {
            Color.clear
                .onTapGesture {
                    dismissKeyboard()
                }
        }
    }
    
    @ViewBuilder
    func loginButtons(viewModel: AuthViewModel) -> some View {
        VStack(spacing: 16) {
            Button {
                dismissKeyboard()
                switch loginType {
                case .login:
                    Task { await viewModel.signInWithEmail() }
                case .register:
                    Task { await viewModel.signUpWithEmail() }
                }
            } label: {
                switch loginTypeAnimated {
                case .login:
                    Text("Anmelden")
                        .font(.cjBody)
                        .frame(maxWidth: .infinity)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .register:
                    Text("Registrieren")
                        .font(.cjBody)
                        .frame(maxWidth: .infinity)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.vertical, 6)
            .buttonStyle(.glassProminent)
            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
            
            Divider().padding(.vertical, 8)
            
            Button {
                Task { await viewModel.signInWithSpotify() }
            } label: {
                HStack {
                    Image("Spotify")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 38)
                    Text("Mit Spotify anmelden")
                        .font(.cjBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(6)
            .background { Color.black }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .disabled(viewModel.isLoading)
        }
    }
    
    @State private var showLoading: Bool = false

    @ViewBuilder
    func loadingOverlay() -> some View {
        VStack {
            Spacer()
            if showLoading {
                VStack {
                    ProgressView()
                        .padding()
                    Text("Laden…")
                        .font(.cjTitle)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .background {
                    Color(uiColor: .systemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                }
                .padding()
                .transition(.move(edge: .bottom))
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            Color.black.opacity(0.1)
                .ignoresSafeArea()
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.bouncy.delay(0.2)) {
                showLoading = true
            }
        }
    }

    func dismissKeyboard() {
        emailTextField = false
        passwordTextField = false
        newPassowrdRepeatTextField = false
    }
    
    enum LoginType: String, CaseIterable {
        case login
        case register
        
        var label: String {
            switch self {
            case .login:
                return "Anmelden"
            case .register:
                return "Registrieren"
            }
        }
    }
}

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
                .map { _ in false}
        )
        .eraseToAnyPublisher()
    }
}
