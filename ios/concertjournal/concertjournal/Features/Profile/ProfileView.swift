//
//  ProfileView.swift
//  concertjournal
//

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
    @State private var showLoginSheet: Bool = false

    @State private var showSaveButton: Bool = false
    @FocusState private var nameTextFieldFocused

    // Computed shorthand
    private var isLoggedIn: Bool {
        if case .loggedIn = dependencies.userSessionManager.state { return true }
        return false
    }

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.loadingState {
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Lade Profil…")
                            .font(.cjBody)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .error:
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("Profil konnte nicht geladen werden")
                            .font(.cjBody)
                        Button("Erneut versuchen") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded:
                    loadedView(viewModel: viewModel)
                        .background {
                            Color.background.ignoresSafeArea()
                        }
                }
            } else {
                LoadingView()
            }
        }
        .background {
            Color.background.ignoresSafeArea()
        }
        .navigationTitle("Profil")
        .task {
            guard viewModel == nil else { return }
            viewModel = ProfileViewModel(
                supabaseClient: dependencies.supabaseClient,
                userProvider: dependencies.userSessionManager
            )
            await viewModel?.load()
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
    }

    // MARK: - Loaded State

    @ViewBuilder
    func loadedView(viewModel: ProfileViewModel) -> some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    // ── Nutzer-Sektion ────────────────────────────────
                    Group {
                        if isLoggedIn {
                            loggedInUserSection(viewModel: viewModel)
                        } else {
                            notLoggedInSection()
                        }
                    }
                    .padding()
                    .rectangleGlass()
                    .padding(.bottom)

                    // ── Einstellungen ─────────────────────────────────
                    Button {
                        HapticManager.shared.navigationTap()
                        navigationManager.push(.faq)
                    } label: {
                        HStack {
                            Label("FAQ", systemImage: "questionmark.circle")
                                .font(.cjBody)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                    .accessibilityIdentifier("faqButton")
                    .buttonStyle(.glass)

                    Button {
                        HapticManager.shared.navigationTap()
                        navigationManager.push(.colorPicker)
                    } label: {
                        HStack {
                            Label("Farbe", systemImage: "paintpalette")
                                .font(.cjBody)
                            Spacer()
                            Circle()
                                .fill(dependencies.colorThemeManager.appTint)
                                .frame(height: 28)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                    .accessibilityIdentifier("colorButton")
                    .buttonStyle(.glass)

                    // ── Account-Aktionen ──────────────────────────────
                    if isLoggedIn {
                        Button(role: .destructive) {
                            HapticManager.shared.buttonTap()
                            viewModel.signOut()
                        } label: {
                            Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.cjBody)
                                .padding(8)
                        }
                        .accessibilityIdentifier("signOutButton")
                        .buttonStyle(.glass)

                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Logged-in User Section

    @ViewBuilder
    func loggedInUserSection(viewModel: ProfileViewModel) -> some View {
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
                ZStack {
                    if viewModel.saveDisplayNameState == .loading {
                        ProgressView()
                    }

                    HStack {
                        let binding = Binding {
                            viewModel.displayName
                        } set: { newValue in
                            viewModel.displayName = newValue
                        }

                        TextField("", text: binding)
                            .font(.cjTitle2)
                            .fontWeight(.semibold)
                            .submitLabel(.done)
                            .focused($nameTextFieldFocused)
                            .onChange(of: viewModel.displayName) { _, newValue in
                                withAnimation {
                                    showSaveButton = viewModel.initialDisplayName != newValue
                                }
                            }
                            .onSubmit {
                                viewModel.saveDisplayName()
                                withAnimation { showSaveButton = false }
                                nameTextFieldFocused = false
                            }

                        if showSaveButton {
                            Button {
                                HapticManager.shared.buttonTap()
                                viewModel.saveDisplayName()
                                withAnimation { showSaveButton = false }
                                nameTextFieldFocused = false
                            } label: {
                                Text("Speichern").font(.cjBody)
                            }
                            .buttonStyle(.glassProminent)
                        }
                    }
                }

                if let email = viewModel.email {
                    Text(email)
                        .font(.cjBody)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Not Logged-in Section

    @ViewBuilder
    func notLoggedInSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.gray.opacity(0.15))
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nicht angemeldet")
                        .font(.cjTitle2)
                        .fontWeight(.semibold)
                    Text("Lokal gespeichert")
                        .font(.cjBody)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("Melde dich an, um deine Konzerte zu sichern und auf allen Geräten zu synchronisieren.")
                .font(.cjFootnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Button {
                HapticManager.shared.buttonTap()
                showLoginSheet = true
            } label: {
                Label("Anmelden / Registrieren", systemImage: "person.badge.plus")
                    .font(.cjBody)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}
