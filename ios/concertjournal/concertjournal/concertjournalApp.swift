//
//  concertjournalApp.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import SwiftUI
import Supabase

@main
struct concertjournalApp: App {
    
    @StateObject private var userManager = UserSessionManager()
    @StateObject private var colorTheme = ColorThemeManager()
    
    @State var isLoading: Bool = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(2.5)
                } else {
                    if userManager.user != nil {
                        ConcertsView(userManager: userManager)
                    } else {
                        LoginView()
                    }
                }
            }
            .tint(colorTheme.appTint)
            .environment(\.appTintColor, colorTheme.appTint)
            .environmentObject(colorTheme)
            .task {
                await userManager.start()
            }
            .task {
                await LocalizationManager.shared.loadLocale("de")
                isLoading = false
            }
            .onOpenURL { url in
                Task {
                    try? await SupabaseManager.shared.client.auth.session(from: url)
                }
            }
        }
    }
}
