//
//  AccountSettingsView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.03.26.
//

import SwiftUI

struct AccountSettingsView: View {

    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss
    @State private var viewModel: AccountSettingsViewModel?

    var body: some View {
        if let viewModel {
            AccountSettingsContent(viewModel: viewModel)
        } else {
            LoadingView()
                .task {
                    viewModel = AccountSettingsViewModel(
                        dependencyContainer: dependencies,
                        supabaseClient: dependencies.supabaseClient,
                        userProvider: dependencies.userSessionManager,
                        photoRepository: dependencies.photoRepository
                    )
                }
        }
    }
}

// MARK: - Content

private struct AccountSettingsContent: View {

    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss

    var viewModel: AccountSettingsViewModel
    @FocusState private var emailFocused: Bool
    @State private var showDeleteConfirmation = false

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            // Background
            LinearGradient(
                colors: [
                    dependencies.colorThemeManager.appTint.opacity(0.3),
                    dependencies.colorThemeManager.appTint.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    
                    // ── Header ────────────────────────────────────────────
                    VStack(spacing: 12) {
                        Text(TextKey.profileAccountSettings.localized)
                            .font(.custom("PlayfairDisplay-Bold", size: 36))
                            .multilineTextAlignment(.center)
                        
                        Text(TextKey.profileAccountManageAccountDesc.localized)
                            .font(.cjBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 48)
                    
                    // ── Email Section ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 20) {
                        sectionHeader(title: TextKey.profileAccountChangeEmail.localized, icon: "envelope.fill")
                        
                        // Current Email Display
                        VStack(alignment: .leading, spacing: 8) {
                            Text(TextKey.profileAccountCurrentEmail.localized)
                                .font(.cjCaption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 16))
                                
                                Text(viewModel.currentEmail)
                                    .font(.cjBody)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                            }
                            .padding(14)
                            .rectangleGlass()
                        }
                        
                        // New Email Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text(TextKey.profileAccountNewEmail.localized)
                                .font(.cjCaption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 16))
                                
                                TextField(TextKey.profileAccountNewEmailPlaceholder.localized, text: $viewModel.newEmail)
                                    .font(.cjBody)
                                    .focused($emailFocused)
                                    .submitLabel(.done)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                
                                if !viewModel.newEmail.isEmpty {
                                    Button {
                                        viewModel.newEmail = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.opacity.combined(with: .scale))
                                }
                            }
                            .padding(14)
                            .rectangleGlass()
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        emailFocused ? dependencies.colorThemeManager.appTint.opacity(0.6) : Color.white.opacity(0.1),
                                        lineWidth: emailFocused ? 1.5 : 0.5
                                    )
                                    .animation(.easeInOut(duration: 0.2), value: emailFocused)
                            }
                            
                            // Validation Message
                            if !viewModel.newEmail.isEmpty && !viewModel.isValidEmail {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Text(TextKey.profileAccountEmailInvalid.localized)
                                        .font(.cjFootnote)
                                        .foregroundStyle(.red)
                                }
                                .padding(.horizontal, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        // Change Email Button
                        if !viewModel.newEmail.isEmpty && viewModel.isValidEmail {
                            Button {
                                emailFocused = false
                                Task { await viewModel.changeEmail() }
                            } label: {
                                ZStack {
                                    if case .loading = viewModel.state {
                                        HStack(spacing: 10) {
                                            FlowerLoading()
                                                .frame(width: 40, height: 40)
                                            Text(TextKey.profileAccountEmailChangeLoading.localized).font(.cjTitle2)
                                        }
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        HStack {
                                            Text(TextKey.profileAccountChangeEmail.localized)
                                                .font(.cjTitle2)
                                            Image(systemName: "checkmark")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.glassProminent)
                            .disabled({
                                if case .loading = viewModel.state { return true }
                                return false
                            }())
                            .tint(dependencies.colorThemeManager.appTint)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                    
                    Spacer()
                    
                    // ── Danger Zone ────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 20) {
                        sectionHeader(title: TextKey.profileAccountDangerZone.localized, icon: "exclamationmark.triangle.fill")
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.15))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "trash.fill")
                                        .font(.title3)
                                        .foregroundStyle(.red)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(TextKey.profileAccountDeleteAccount.localized)
                                        .font(.cjHeadline)
                                        .foregroundStyle(.primary)
                                    
                                    Text(TextKey.profileAccountDeleteAccountDesc.localized)
                                        .font(.cjFootnote)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text(TextKey.profileAccountDeleteAccountDelete.localized)
                                }
                                .font(.cjTitle2)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.red)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
            }
            .scrollIndicators(.hidden)
        }
        .onTapGesture { emailFocused = false }
        .adaptiveSheet(isPresented: $showDeleteConfirmation) {
            deleteAccountDialog(viewModel: viewModel)
        }

        // Error Message
        if case .error(let msg) = viewModel.state {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(.cjBody)
                        .foregroundStyle(.red)
                    Spacer()
                    Button {
                        viewModel.state = .idle
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(16)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(dependencies.colorThemeManager.appTint)
            Text(title)
                .font(.cjTitle)
        }
    }

    @ViewBuilder
    private func deleteAccountDialog(viewModel: AccountSettingsViewModel) -> some View {
        @State var loading: Bool = false

        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text(TextKey.profileAccountDeleteDialogTitle.localized)
                .font(.cjTitle)
                .multilineTextAlignment(.center)

            Text(TextKey.profileAccountDeleteDialogMessage.localized)
                .font(.cjBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                Button(role: .destructive) {
                    HapticManager.shared.impact(.heavy)
                    Task {
                        do {
                            loading = true
                            try await viewModel.deleteAccount()
                            loading = false
                            HapticManager.shared.success()
                            // Account gelöscht - navigate zurück
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                dismiss()
                            }
                        } catch {
                            logError("Account deletion failed", error: error)
                            loading = false
                        }
                    }
                } label: {
                    if loading {
                        FlowerLoading()
                            .frame(width: 40, height: 40)
                    } else {
                        Text(TextKey.profileAccountDeleteDialogConfirm.localized)
                            .font(.cjHeadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .foregroundStyle(.white)
                .cornerRadius(16)
                .disabled(loading)

                Button {
                    HapticManager.shared.impact(.light)
                    showDeleteConfirmation = false
                } label: {
                    Text(TextKey.genericCancel.localized)
                        .font(.cjHeadline)
                }
                .buttonStyle(ModernButtonStyle(style: .glass, color: dependencies.colorThemeManager.appTint))
            }
        }
        .padding(24)
    }
}
