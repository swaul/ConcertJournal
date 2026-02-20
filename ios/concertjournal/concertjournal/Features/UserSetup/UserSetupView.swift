//
//  UserSetupView.swift
//  concertjournal
//
//  Created by Paul Arbetit on 19.02.26.
//

import PhotosUI
import SwiftUI

struct UserSetupView: View {
    
    @Environment(\.dependencies) var dependencies
    @State private var viewModel: UserSetupViewModel?
    
    // Callback wenn Setup abgeschlossen
    let onComplete: () -> Void
    
    var body: some View {
        if let viewModel {
            UserSetupContent(viewModel: viewModel)
        } else {
            LoadingView()
                .onAppear {
                    viewModel = UserSetupViewModel(
                        supabaseClient: dependencies.supabaseClient,
                        userProvider: dependencies.userSessionManager,
                        onComplete: onComplete
                    )
                }
        }
    }
}

// MARK: - Content

private struct UserSetupContent: View {
    
    @Environment(\.dependencies) var dependencies
    
    var viewModel: UserSetupViewModel
    @FocusState private var nameFocused: Bool
    
    var body: some View {
        ZStack {
            // Background – gleich wie im Onboarding
            LinearGradient(
                colors: [
                    dependencies.colorThemeManager.appTint.opacity(0.3),
                    dependencies.colorThemeManager.appTint.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // ── Header ────────────────────────────────────────────
                VStack(spacing: 12) {
                    Text(TextKey.almostDone.localized)
                        .font(.custom("PlayfairDisplay-Bold", size: 36))
                        .multilineTextAlignment(.center)
                    
                    Text(TextKey.profileNameQuestion.localized)
                        .font(.cjBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 48)
                
                // ── Avatar Picker ─────────────────────────────────────
                AvatarPickerSection(viewModel: viewModel)
                    .padding(.bottom, 40)
                
                // ── Name Input ────────────────────────────────────────
                NameInputSection(viewModel: viewModel, nameFocused: $nameFocused)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                // ── CTA ───────────────────────────────────────────────
                VStack(spacing: 12) {
                    saveButton()
                    
                    // Skip-Option ohne Foto
                    if viewModel.selectedImage == nil && !viewModel.displayName.isEmpty {
                        Button {
                            nameFocused = false
                        } label: {
                            Text(TextKey.addPhotoLater.localized)
                                .font(.cjFootnote)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onTapGesture { nameFocused = false }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task { await viewModel.loadSelectedPhoto() }
        }
    }
    
    // MARK: - Save Button
    
    @ViewBuilder
    private func saveButton() -> some View {
        Button {
            nameFocused = false
            Task { await viewModel.save() }
        } label: {
            ZStack {
                if case .loading = viewModel.state {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Speichern…").font(.cjTitle2)
                    }
                    .frame(maxWidth: .infinity)
                } else if case .success = viewModel.state {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(TextKey.successUpdatesSaved.localized).font(.cjTitle2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.green)
                } else {
                    HStack {
                        Text(TextKey.letsGo.localized)
                            .font(.cjTitle2)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .disabled(!viewModel.canProceed || {
            if case .loading = viewModel.state { return true }
            if case .success = viewModel.state { return true }
            return false
        }())
        .animation(.spring(response: 0.3), value: viewModel.canProceed)
        .tint(dependencies.colorThemeManager.appTint)
        
        // Fehler
        if case .error(let msg) = viewModel.state {
            Text(msg)
                .font(.cjFootnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

// MARK: - Avatar Picker Section

private struct AvatarPickerSection: View {
    @Environment(\.dependencies) var dependencies

    @State var viewModel: UserSetupViewModel
    @State private var isPressed = false
    
    var body: some View {
        PhotosPicker(
            selection: $viewModel.selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                // Avatar oder Placeholder
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 2)
                        }
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .overlay {
                            Circle().stroke(.white.opacity(0.15), lineWidth: 1)
                        }
                        .overlay {
                            if viewModel.isUploadingAvatar {
                                ProgressView()
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.secondary)
                                    Text(TextKey.fieldPhoto.localized)
                                        .font(.cjFootnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
                
                // Edit-Badge
                Circle()
                    .fill(dependencies.colorThemeManager.appTint)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: viewModel.selectedImage != nil ? "pencil" : "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(radius: 4, y: 2)
                    .offset(x: 40, y: 40)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Name Input Section

private struct NameInputSection: View {
    @Environment(\.dependencies) var dependencies

    @State var viewModel: UserSetupViewModel
    var nameFocused: FocusState<Bool>.Binding
    
    private var characterCount: Int { viewModel.displayName.count }
    private let maxLength = 30
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            HStack {
                Text(TextKey.fieldDisplayName.localized)
                    .font(.cjHeadline)
                Spacer()
                Text("\(characterCount)/\(maxLength)")
                    .font(.cjFootnote)
                    .foregroundStyle(characterCount > maxLength ? .red : .secondary)
                    .animation(.spring(response: 0.2), value: characterCount)
            }
            .padding(.horizontal, 4)
            
            // Textfeld
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16))
                
                TextField("z.B. Max Mustermann", text: $viewModel.displayName)
                    .font(.cjBody)
                    .focused(nameFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.displayName) { _, newValue in
                        if newValue.count > maxLength {
                            viewModel.displayName = String(newValue.prefix(maxLength))
                        }
                    }
                
                if !viewModel.displayName.isEmpty {
                    Button {
                        viewModel.displayName = ""
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
                        nameFocused.wrappedValue ? dependencies.colorThemeManager.appTint.opacity(0.6) : Color.white.opacity(0.1),
                        lineWidth: nameFocused.wrappedValue ? 1.5 : 0.5
                    )
                    .animation(.easeInOut(duration: 0.2), value: nameFocused.wrappedValue)
            }
            
            // Hinweis
            Text(TextKey.fieldDisplayNameHint.localized)
                .font(.cjFootnote)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }
}
