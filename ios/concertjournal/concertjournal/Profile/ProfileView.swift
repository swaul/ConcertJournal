import Combine
import SwiftUI
import Supabase

protocol UserProviding {
    var user: User? { get }
    
    func loadUser() async throws -> User
}

enum ProfileState {
    case loading
    case error
    case loaded
}

final class ProfileViewModel: ObservableObject {
    var initialDisplayName: String = ""
    @Published var displayName: String = ""
    @Published var email: String? = nil
    
    @Published var loadingState: ProfileState = .loading
    @Published var saveDisplayNameState: ProfileState = .loaded
    
    let userProvider: UserProviding
    
    init(userProvider: UserProviding) {
        self.userProvider = userProvider
    }

    @MainActor
    func load() async {
        do {
            loadingState = .loading
            if let user = userProvider.user {
                loadingState = .loaded
                fillView(with: user)
            } else {
                let user = try await userProvider.loadUser()
                loadingState = .loaded
                fillView(with: user)
            }
        } catch {
            loadingState = .error
            print("ERROR LOADING USER DATA")
        }
    }
    
    private func fillView(with user: User) {
        email = user.email
        displayName = user.userMetadata["display_name"]?.stringValue ?? "Your name"
        initialDisplayName = displayName
    }
    
    func saveDisplayName() {
        Task {
            do {
                saveDisplayNameState = .loading
                let userAttributes = UserAttributes(data: ["display_name": .string(displayName)])
                try await SupabaseManager.shared.client.auth.update(user: userAttributes)
                saveDisplayNameState = .loaded
            } catch {
                saveDisplayNameState = .error
            }
        }
    }
}

struct ProfileView: View {
    
    @EnvironmentObject private var navigationManager: NavigationManager
    
    @StateObject private var viewModel: ProfileViewModel

    @State private var showSaveButton: Bool = false
    @FocusState private var nameTextFieldFocused
    
    init(viewModel: ProfileViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack {
            Group {
                switch viewModel.loadingState {
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading profile…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .error:
                    Text("ERROR")
                case .loaded:
                    List {
                        Section {
                            userSection
                                .padding(.vertical, 4)
                        }
                        
                        Section {
                            Button {
                                navigationManager.push(view: .faq)
                            } label: {
                                HStack {
                                    Text("FAQ")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .accessibilityIdentifier("faqButton")
                        }
                        
                        Section {
                            Button(role: .destructive) {
                                print("sign out")
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out")
                                }
                            }
                            .accessibilityIdentifier("signOutButton")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
        .task { await viewModel.load() }
    }
    
    var userSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.gray.opacity(0.2))
                Image(systemName: "person.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 4) {
                let binding = Binding {
                    viewModel.displayName
                } set: { displayName in
                    viewModel.displayName = displayName
                }

                ZStack {
                    if viewModel.saveDisplayNameState == .loading {
                        ProgressView()
                    }
                    HStack {
                        TextField("", text: binding)
                            .font(.title3).fontWeight(.semibold)
                            .submitLabel(.done)
                            .focused($nameTextFieldFocused)
                            .onChange(of: viewModel.displayName, { _, newValue in
                                withAnimation {
                                    showSaveButton = viewModel.initialDisplayName != newValue
                                }
                            })
                            .onSubmit {
                                viewModel.saveDisplayName()
                                withAnimation {
                                    showSaveButton = false
                                }
                                nameTextFieldFocused = false
                            }
                        if showSaveButton {
                            Button {
                                viewModel.saveDisplayName()
                                withAnimation {
                                    showSaveButton = false
                                }
                                nameTextFieldFocused = false
                            } label: {
                                Text("Save")
                            }
                            .buttonStyle(.glassProminent)
                        }
                    }
                }
                
                if let email = viewModel.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

#Preview("Default") {
    ProfileView(viewModel: ProfileViewModel(userProvider: UserSessionManager()))
}

