import Combine
import SwiftUI
import Supabase

enum ProfileState {
    case loading
    case error
    case loaded
}

struct ProfileView: View {

    @Environment(\.dependencies) var dependencies
    @Environment(\.navigationManager) var navigationManager

    @State private var viewModel: ProfileViewModel?

    @State private var showSaveButton: Bool = false
    @FocusState private var nameTextFieldFocused

    var body: some View {
        Group {
            if let viewModel {
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
                                    userSection(viewModel: viewModel)
                                        .padding(.vertical, 4)
                                }

                                Section {
                                    Button {
                                        navigationManager.push(.faq)
                                    } label: {
                                        HStack {
                                            Text("FAQ")
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                    }
                                    .accessibilityIdentifier("faqButton")

                                    Button {
                                        navigationManager.push(.colorPicker)
                                    } label: {
                                        HStack {
                                            Text("Color")
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                    }
                                    .accessibilityIdentifier("colorButton")
                                }

                                Section {
                                    Button(role: .destructive) {
                                        print("sign out")
                                        viewModel.signOut()
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
                }
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Profile")
        .task {
            guard viewModel == nil else { return }
            viewModel = ProfileViewModel(supabaseClient: dependencies.supabaseClient,
                                         userProvider: dependencies.userSessionManager)
            await viewModel?.load()
        }
    }

    @ViewBuilder
    func userSection(viewModel: ProfileViewModel) -> some View {
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
    ProfileView()
}

