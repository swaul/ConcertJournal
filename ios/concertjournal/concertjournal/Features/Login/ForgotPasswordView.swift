//
//  PasswordResetView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 09.02.26.
//

import SwiftUI
import Supabase

struct ForgotPasswordView: View {
    
    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss
    
    init(email: String) {
        self._email = State(initialValue: email)
    }
    
    @State var email: String
    @State private var confirmationText: ConfirmationMessage? = nil
    @State private var savingConcertPresenting: Bool = false
    @State private var confirmationTextPresenting: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                
                Text(TextKey.forgotPasswordDesc.localized)
                    .font(.cjBody)
                    .padding()
                
                EmailValidatedTextField("E-Mail", text: $email)
                    .frame(maxWidth: .infinity)
                    .padding()
                
                
                Spacer()
                
                Button {
                    initiatePasswordReset()
                } label: {
                    Text(TextKey.sendResetLink.localized)
                        .font(.cjBody)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding()
            }
            .sheet(isPresented: $confirmationTextPresenting) {
                if let confirmationText {
                    ConfirmationView(message: confirmationText, isPresented: $confirmationTextPresenting)
                }
            }
            .sheet(isPresented: $savingConcertPresenting) {
                LoadingSheet(message: "Email versenden..")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.shared.navigationTap()
                        dismiss()
                    } label: {
                        Text(TextKey.cancel.localized)
                            .font(.cjBody)
                    }
                }
            }
            .navigationTitle("Passwort vergessen")
        }
    }
    
    func initiatePasswordReset() {
        Task {
            savingConcertPresenting = true
            try await dependencies.supabaseClient.client.auth.resetPasswordForEmail(email, redirectTo: URL(string: "https://swaul.github.io/ConcertJournal/reset-password.html"))
            savingConcertPresenting = false
            confirmationText = ConfirmationMessage(message: "Email gesendet 🎉") {
                dismiss()
            }
            confirmationTextPresenting = true
        }
    }
}
