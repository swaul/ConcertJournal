import SwiftUI
import SpotifyiOS

struct LoginView: View {
        
    @StateObject var vm = AuthViewModel()

    @State private var showPassword = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Email", text: $vm.email)
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
                            TextField("Password", text: $vm.password)
                                .textInputAutocapitalization(.never)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Password", text: $vm.password)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await vm.signInWithEmail() }
                    } label: {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty)

                    Button {
                        Task { await vm.signUpWithEmail() }
                    } label: {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty)
                }

                Divider().padding(.vertical, 8)

                Button {
                    Task { await vm.signInWithSpotify() }
                } label: {
                    HStack {
                        Image("Spotify")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 38)
                        Text(LocalizationManager.shared.text(for: "spotifyLoginButton"))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading)
            }
            .padding()
            .navigationTitle(LocalizationManager.shared.text(for: "loginTitle"))
        }
    }
}

#Preview {
    LoginView()
}
