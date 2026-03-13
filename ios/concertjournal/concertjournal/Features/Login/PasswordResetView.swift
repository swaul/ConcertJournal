//
//  PasswordResetView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI
import Supabase

struct PasswordResetView: View {

    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss

    let passwordResetRequest: PasswordResetRequest

    @State private var errorMessage: String?

    @State private var newPasswordText: String = ""
    @State private var repeatNewPasswordText: String = ""

    @State private var confirmationText: ConfirmationMessage? = nil
    @State private var loadingPasswordChangePresenting: Bool = false
    @State private var confirmationTextPresenting: Bool = false

    @FocusState private var newPasswordTextField: Bool
    @FocusState private var repeatNewPasswordTextField: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {

                Text(TextKey.passwordresetDesc.localized)
                    .font(.cjBody)
                    .padding()

                SecureField(TextKey.passwordresetNewPassword.localized, text: $newPasswordText)
                    .font(.cjBody)
                    .textContentType(.newPassword)
                    .focused($newPasswordTextField)
                    .submitLabel(.next)
                    .padding()
                    .glassEffect()
                    .onSubmit {
                        repeatNewPasswordTextField = true
                    }

                SecureField(TextKey.passwordresetRepeatPassword.localized, text: $repeatNewPasswordText)
                    .font(.cjBody)
                    .textContentType(.newPassword)
                    .focused($repeatNewPasswordTextField)
                    .submitLabel(.send)
                    .padding()
                    .glassEffect()
                    .onSubmit {
                        resetPassword()
                    }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                Spacer()

                Button {
                    resetPassword()
                } label: {
                    Text(TextKey.passwordresetChangePassword.localized)
                        .font(.cjBody)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding()
            }
            .padding()
            .task {
                await verifyCode()
            }
            .adaptiveSheet(isPresented: $confirmationTextPresenting) {
                if let confirmationText {
                    ConfirmationView(message: confirmationText, isPresented: $confirmationTextPresenting)
                }
            }
            .sheet(isPresented: $loadingPasswordChangePresenting) {
                LoadingSheet(message: TextKey.passwordresetChanging.localized)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    } label: {
                        Text(TextKey.genericCancel.localized)
                            .font(.cjBody)
                    }
                }
            }
            .navigationTitle(TextKey.passwordresetTitle.localized)
            .interactiveDismissDisabled()
        }
    }

    func verifyCode() async {
        do {
            let _ = try await dependencies.supabaseClient.client.auth.exchangeCodeForSession(authCode: passwordResetRequest.code)
            logSuccess("Code verified, session created")
        } catch {
            errorMessage = TextKey.passwordresetLinkInvalid.localized
            logError("Code verification failed", error: error)
        }
    }

    func resetPassword() {
        Task {
            guard newPasswordText == repeatNewPasswordText else {
                errorMessage = TextKey.passwordresetNotMatching.localized
                return
            }

            guard newPasswordText.count >= 6 else {
                errorMessage = TextKey.passwordresetTooShort.localized
                return
            }

            loadingPasswordChangePresenting = true
            errorMessage = nil

            do {
                try await dependencies.supabaseClient.client.auth.update(user: UserAttributes(password: newPasswordText))

                loadingPasswordChangePresenting = false
                confirmationText = ConfirmationMessage(message: TextKey.passwordresetChanged.localized) {
                    dismiss()
                }
                confirmationTextPresenting = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
