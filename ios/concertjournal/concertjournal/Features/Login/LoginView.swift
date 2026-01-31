import SwiftUI
import SpotifyiOS

struct LoginView: View {

    @Environment(\.dependencies) var dependencies

    @State var viewModel: AuthViewModel?

    @State private var showPassword = false
    
    var body: some View {
        Group {
            if let viewModel {
                @Bindable var viewModel = viewModel
                NavigationStack {
                    VStack(spacing: 16) {

                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Email", text: $viewModel.email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textFieldStyle(.roundedBorder)

                            ZStack {
                                HStack {
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            showPassword.toggle()
                                        }
                                    } label: {
                                        showPassword ? Image(systemName: "eye") : Image(systemName: "eye.slash")
                                    }
                                }
                                if showPassword {
                                    TextField("Password", text: $viewModel.password)
                                        .textInputAutocapitalization(.never)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("Password", text: $viewModel.password)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }

                        HStack(spacing: 12) {
                            Button {
                                Task { await viewModel.signInWithEmail() }
                            } label: {
                                Text("Sign In")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)

                            Button {
                                Task { await viewModel.signUpWithEmail() }
                            } label: {
                                Text("Sign Up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                        }

                        Divider().padding(.vertical, 8)

                        Button {
                            Task { await viewModel.signInWithSpotify() }
                        } label: {
                            HStack {
                                Image("Spotify")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 38)
                                Text(dependencies.localizationRepository.text(for: "spotifyLoginButton"))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)
                    }
                    .padding()
                    .navigationTitle(dependencies.localizationRepository.text(for: "loginTitle"))
                }
            } else {

            }
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = AuthViewModel(supabaseClient: dependencies.supabaseClient)
        }
    }
}

#Preview {
    LoginView()
}
