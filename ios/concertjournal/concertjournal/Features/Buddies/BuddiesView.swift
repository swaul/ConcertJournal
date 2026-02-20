//
//  BuddiesView.swift
//  concertjournal
//

import SwiftUI

struct BuddiesView: View {
    
    @Environment(\.dependencies) var dependencies
    @State private var viewModel: BuddiesViewModel?
    @State private var showRequestsSheet = false
    @State private var showAddBuddySheet = false
    
    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.loadingState {
                case .loading:
                    loadingView()
                case .error:
                    errorView(viewModel: viewModel)
                case .loaded:
                    loadedView(viewModel: viewModel)
                }
            } else {
                LoadingView()
            }
        }
        .background { Color.background.ignoresSafeArea() }
        .navigationTitle("Buddies")
        .task {
            guard viewModel == nil else { return }
            viewModel = BuddiesViewModel(
                supabaseClient: dependencies.supabaseClient,
                userProvider: dependencies.userSessionManager
            )
            await viewModel?.load()
        }
    }
    
    // MARK: - Loading
    
    @ViewBuilder
    private func loadingView() -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(TextKey.buddiesLoading.localized)
                .font(.cjBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error
    
    @ViewBuilder
    private func errorView(viewModel: BuddiesViewModel) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(TextKey.buddiesLoadError.localized)
                .font(.cjBody)
            
            Button(TextKey.retryAgain.localized) { Task { await viewModel.load() } }
                .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Loaded
    
    @ViewBuilder
    private func loadedView(viewModel: BuddiesViewModel) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    
                    // ── Mein Code ─────────────────────────────────────
                    MyCodeCard(viewModel: viewModel)
                    
                    // ── Anfragen-Banner ───────────────────────────────
                    if !viewModel.incomingRequests.isEmpty || !viewModel.outgoingRequests.isEmpty {
                        requestsBanner(viewModel: viewModel)
                    }
                    
                    // ── Buddy-Liste ───────────────────────────────────
                    if viewModel.buddies.isEmpty {
                        emptyBuddiesView()
                    } else {
                        ForEach(viewModel.buddies) { buddy in
                            BuddyRow(buddy: buddy) {
                                Task { await viewModel.removeBuddy(buddy) }
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await viewModel.load() }
            
            // ── FAB ───────────────────────────────────────────────
            addBuddyFAB()
        }
        .sheet(isPresented: $showRequestsSheet) {
            RequestsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddBuddySheet) {
            AddBuddySheet(viewModel: viewModel)
        }
        .alert(TextKey.errorGeneric.localized, isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(TextKey.ok.localized, role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Anfragen-Banner
    
    @ViewBuilder
    private func requestsBanner(viewModel: BuddiesViewModel) -> some View {
        Button {
            HapticManager.shared.navigationTap()
            showRequestsSheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.tint)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    // TODO: LOCALIZATION
                    Text("\(viewModel.incomingRequests.count) neue Anfrage\(viewModel.incomingRequests.count == 1 ? "" : "n")")
                        .font(.cjHeadline)
                        .foregroundStyle(.primary)
                    Text(TextKey.buddiesTapToReply.localized)
                        .font(.cjFootnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .padding(12)
        }
        .buttonStyle(.glass)
        .overlay(alignment: .topTrailing) {
            Circle().fill(.tint).frame(width: 10, height: 10).offset(x: -8, y: 8)
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private func emptyBuddiesView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .padding(.top, 40)
            Text(TextKey.buddiesNone.localized)
                .font(.cjTitle2)
                .fontWeight(.semibold)
            Text(TextKey.buddiesShareCode.localized)
                .font(.cjBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - FAB
    
    @ViewBuilder
    private func addBuddyFAB() -> some View {
        Button {
            HapticManager.shared.buttonTap()
            showAddBuddySheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                
                Text(TextKey.addBuddy.localized)
                    .font(.cjBody)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.glassProminent)
        .padding(.bottom, 24)
        .shadow(radius: 12, y: 4)
    }
}

// MARK: - MyCodeCard

private struct MyCodeCard: View {
    var viewModel: BuddiesViewModel
    @State private var showQR = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(TextKey.buddiesMyCode.localized, systemImage: "qrcode")
                    .font(.cjHeadline)
                Spacer()
                Button {
                    HapticManager.shared.buttonTap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showQR.toggle()
                    }
                } label: {
                    Image(systemName: showQR ? "chevron.up" : "qrcode.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 32, height: 32)
                        .background(.tint.opacity(0.12), in: Circle())
                }
            }
            .padding(.bottom, 14)
            
            // Code-Anzeige
            if let code = viewModel.myBuddyCode {
                HStack(spacing: 6) {
                    ForEach(Array(code.enumerated()), id: \.offset) { index, char in
                        Text(String(char))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 46)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
                            }
                    }
                    
                    Spacer()
                    
                    // Kopieren
                    Button {
                        UIPasteboard.general.string = code
                        HapticManager.shared.buttonTap()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 15))
                            .foregroundStyle(.tint)
                            .frame(width: 36, height: 36)
                            .background(.tint.opacity(0.12), in: Circle())
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            
            // QR-Code (aufklappbar)
            if showQR {
                VStack(spacing: 14) {
                    Divider().padding(.vertical, 6)
                    
                    if let qr = viewModel.qrImage {
                        Image(uiImage: qr)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(8)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        ProgressView()
                            .frame(width: 200, height: 200)
                    }
                    
                    Text(TextKey.buddiesLetFriendScan.localized)
                        .font(.cjFootnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Code neu generieren
                    Button {
                        Task { await viewModel.regenerateBuddyCode() }
                    } label: {
                        if viewModel.isRegeneratingCode {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.8)
                                Text("Generiere…")
                                    .font(.cjFootnote)
                            }
                        } else {
                            Label(TextKey.generateNewCode, systemImage: "arrow.clockwise")
                                .font(.cjFootnote)
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.isRegeneratingCode)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}

// MARK: - BuddyRow

private struct BuddyRow: View {
    let buddy: Buddy
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            AvatarView(url: buddy.avatarURL, name: buddy.displayName, size: 52)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(buddy.displayName)
                    .font(.cjHeadline)
                    .foregroundStyle(.primary)
                // TODO: LOCALIZATION
                Label("\(buddy.sharedConcerts) gemeinsame Konzerte", systemImage: "music.note.list")
                    .font(.cjFootnote)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(buddy.lastActivity.formatted(.relative(presentation: .named)))
                    .font(.cjFootnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        }
        .contextMenu {
            Button(role: .destructive) { onRemove() } label: {
                Label(TextKey.endFriendship, systemImage: "person.fill.xmark")
            }
        }
    }
}

// MARK: - Requests Sheet

private struct RequestsSheet: View {
    var viewModel: BuddiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                
                if viewModel.incomingRequests.isEmpty && viewModel.outgoingRequests.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48)).foregroundStyle(.green)
                        Text(TextKey.buddiesNoRequests.localized)
                            .font(.cjBody).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if !viewModel.incomingRequests.isEmpty {
                                requestSection(title: TextKey.buddiesIncoming.localized, icon: "arrow.down.circle.fill",
                                               iconColor: .green, requests: viewModel.incomingRequests)
                            }
                            if !viewModel.outgoingRequests.isEmpty {
                                requestSection(title: TextKey.buddiesOutgoing.localized, icon: "arrow.up.circle.fill",
                                               iconColor: .orange, requests: viewModel.outgoingRequests)
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(TextKey.navRequests.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(TextKey.done.localized) { dismiss() }.font(.cjBody.bold())
                }
            }
        }
    }
    
    @ViewBuilder
    private func requestSection(title: String, icon: String, iconColor: Color, requests: [BuddyRequest]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.cjHeadline).foregroundStyle(iconColor).padding(.leading, 4)
            ForEach(requests) { request in RequestRow(request: request, viewModel: viewModel) }
        }
    }
}

private struct RequestRow: View {
    let request: BuddyRequest
    var viewModel: BuddiesViewModel
    
    var body: some View {
        HStack(spacing: 14) {
            AvatarView(url: request.avatarURL, name: request.displayName, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName).font(.cjHeadline)
                Text(request.createdAt.formatted(.relative(presentation: .named)))
                    .font(.cjFootnote).foregroundStyle(.secondary)
            }
            Spacer()
            
            if request.direction == .incoming {
                HStack(spacing: 8) {
                    Button { Task { await viewModel.declineRequest(request) } } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass).tint(.red)
                    
                    Button { Task { await viewModel.acceptRequest(request) } } label: {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                HStack(spacing: 8) {
                    // TODO: LOCALIZATION
                    Text("Ausstehend")
                        .font(.cjFootnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                    
                    Button {
                        Task { await viewModel.cancelRequest(request) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)
                    .tint(.red)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 0.5) }
    }
}

// MARK: - Add Buddy Sheet

private struct AddBuddySheet: View {
    @State var viewModel: BuddiesViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @FocusState private var searchFocused: Bool
    @State private var showScanner = false
    
    var body: some View {        
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // ── Suchfeld + Scan-Button ────────────────────────
                    HStack(spacing: 10) {
                        Image(systemName: "number")
                            .foregroundStyle(.secondary)
                        
                        // TODO: LOCALIZATION
                        TextField("6-stelliger Code z.B. AB3X7K", text: $viewModel.searchQuery)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .onChange(of: viewModel.searchQuery) { _, _ in
                                Task { await viewModel.searchUsers() }
                            }
                            .onSubmit {
                                Task { await viewModel.searchUsers() }
                            }
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                HapticManager.shared.buttonTap()
                                viewModel.clearSearch()
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // QR Scanner
                        Button {
                            HapticManager.shared.buttonTap()
                            showScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.tint)
                                .frame(width: 36, height: 36)
                                .background(.tint.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    
                    // Eingabe-Fortschritt
                    if !viewModel.searchQuery.isEmpty && viewModel.searchQuery.count < 6 {
                        HStack(spacing: 6) {
                            ForEach(0..<6, id: \.self) { i in
                                Capsule()
                                    .fill(i < viewModel.searchQuery.count ? dependencies.colorThemeManager.appTint : dependencies.colorThemeManager.appTint.opacity(0.3))
                                    .frame(height: 3)
                            }
                        }
                        .padding(.horizontal)
                        .animation(.spring(response: 0.3), value: viewModel.searchQuery.count)
                    }
                    
                    searchResultsView()
                }
                .padding(.top)
            }
            .navigationTitle(TextKey.navBuddyAdd.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(TextKey.cancel.localized) { viewModel.clearSearch(); dismiss() }.font(.cjBody)
                }
            }
            .onAppear { searchFocused = true }
            .sheet(isPresented: $showScanner) {
                NavigationStack {
                    QRScannerView { scanned in
                        Task { await viewModel.handleScannedCode(scanned) }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func searchResultsView() -> some View {
        switch viewModel.searchState {
        case .idle:
            VStack(spacing: 14) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 44)).foregroundStyle(.secondary)
                Text(TextKey.buddiesCodeHint.localized)
                    .font(.cjBody).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .searching:
            VStack(spacing: 12) {
                ProgressView()
                Text(TextKey.buddiesSearchUser.localized)
                    .font(.cjBody).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .empty:
            VStack(spacing: 12) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 44)).foregroundStyle(.secondary)
                Text(TextKey.buddiesCodeNotFound.localized)
                    .font(.cjBody).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .error:
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44)).foregroundStyle(.orange)
                
                // TODO: LOCALIZATION
                Text("Suche fehlgeschlagen").font(.cjBody).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .results:
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.searchResults) { result in
                        SearchResultRow(result: result) {
                            Task { await viewModel.sendRequest(to: result.id) }
                        }
                    }
                }
                .padding(.horizontal).padding(.bottom)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct SearchResultRow: View {
    let result: UserSearchResult
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            AvatarView(url: result.avatarURL, name: result.displayName, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName).font(.cjHeadline)
                if let code = result.buddyCode {
                    Text(code).font(.system(.footnote, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            switch result.relationStatus {
            case .none:
                Button {
                    HapticManager.shared.buttonTap()
                    onAdd()
                } label: {
                    Label(TextKey.addBuddy.localized, systemImage: "person.badge.plus").font(.cjFootnote)
                }
                .buttonStyle(.glassProminent)
                
            case .pending:
                // TODO: LOCALIZATION
                Label("Ausstehend", systemImage: "clock").font(.cjFootnote).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                
            case .alreadyFriends:
                Label("Buddy", systemImage: "checkmark.circle.fill").font(.cjFootnote).foregroundStyle(.green)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 0.5) }
    }
}

// MARK: - Avatar Helper

struct AvatarView: View {
    let url: URL?
    let name: String
    let size: CGFloat
    
    private var initials: String {
        name.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined().uppercased()
    }
    
    var body: some View {
        ZStack {
            Circle().fill(.tint.opacity(0.2))
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Text(initials).font(.system(size: size * 0.35, weight: .semibold)).foregroundStyle(.tint)
                }
            } else {
                Text(initials).font(.system(size: size * 0.35, weight: .semibold)).foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
