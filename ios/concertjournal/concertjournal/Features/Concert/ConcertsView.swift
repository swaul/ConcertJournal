//
//  ConcertsView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.12.25.
//

import SwiftUI
import Combine

enum ScrollOffsetNamespace {
    static let namespace = "scrollView"
}

struct ConcertsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager

    @State private var viewModel: ConcertsViewModel? = nil

    @State private var chooseCreateFlowPresenting: Bool = false
    @State private var concertToDelete: Concert? = nil
    @State private var confirmationText: ConfirmationMessage? = nil

    @State var fullSizeTodaysConcert = true

    var body: some View {
        @Bindable var navigationManager = navigationManager

        NavigationStack(path: $navigationManager.path) {
            Group {
                if let viewModel, !viewModel.isLoading {
                    if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(dependencies.colorThemeManager.appTint)

                            Text(errorMessage)
                                .font(.cjBody)
                                .multilineTextAlignment(.center)

                            Button {
                                Task {
                                    HapticManager.shared.impact(.medium)
                                    await viewModel.refreshConcerts()
                                    HapticManager.shared.success()
                                }
                            } label: {
                                Label(TextKey.reload.localized, systemImage: "arrow.counterclockwise")
                                    .font(.cjHeadline)
                            }
                            .buttonStyle(ModernButtonStyle(style: .prominent,
                                                           color: dependencies.colorThemeManager.appTint))
                        }
                        .padding()
                    } else if viewModel.futureConcerts.isEmpty && viewModel.pastConcerts.isEmpty {
                        VStack(spacing: 24) {
                            Spacer()

                            Image(systemName: "music.note.list")
                                .font(.system(size: 80))
                                .foregroundStyle(dependencies.colorThemeManager.appTint.opacity(0.6))

                            Text(TextKey.homeNoConcerts.localized)
                                .font(.cjTitle)

                            Text(TextKey.homeAddFirstCta.localized)
                                .font(.cjBody)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Button {
                                HapticManager.shared.impact(.medium)
                                navigationManager.push(.createConcert)
                            } label: {
                                Label(TextKey.homeAddFirst.localized, systemImage: "plus.circle.fill")
                                    .font(.cjHeadline)
                            }
                            .buttonStyle(.glassProminent)

                            Spacer()
                        }
                        .padding()
                        .ignoresSafeArea()
                        .background(Color.background)
                    } else {
                        viewWithViewModel(viewModel: viewModel)
                    }
                } else {
                    LoadingView()
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.background)
            .task {
                if viewModel == nil {
                    viewModel = ConcertsViewModel(repository: dependencies.offlineConcertRepository,
                                                  syncManager: dependencies.syncManager)
                } else {
                    viewModel?.updateConcerts()
                }
            }
            .adaptiveSheet(isPresented: $chooseCreateFlowPresenting) {
                VStack(spacing: 20) {
                    Text(TextKey.concertCreateHow.localized)
                        .font(.cjTitle)
                        .padding()

                    Button {
                        HapticManager.shared.impact(.light)
                        chooseCreateFlowPresenting = false
                        navigationManager.push(.createConcert)
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(TextKey.createManually.localized)
                                    .font(.cjHeadline)
                                Text(TextKey.enterAllDetailsManually.localized)
                                    .font(.cjCaption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal)

                    ZStack(alignment: .topTrailing) {
                        Button {
                            HapticManager.shared.impact(.light)
                            chooseCreateFlowPresenting = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigationManager.push(.ticketScan)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.viewfinder")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(TextKey.createWithTicket.localized)
                                        .font(.cjHeadline)
                                    Text(TextKey.scanTicketAuto.localized)
                                        .font(.cjCaption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.glass)

                        Text(TextKey.infoBeta.localized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(dependencies.colorThemeManager.appTint)
                            .clipShape(Capsule())
                            .offset(x: -8, y: -8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
            .navigationDestination(for: NavigationRoute.self) { route in
                navigationDestination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.impact(.light)
                        navigationManager.push(.profile)
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                    }
                }
            }
        }
        .onReceive(dependencies.userSessionManager.userSessionChanged) { user in
            if user == nil {
                navigationManager.popToRoot()
                HapticManager.shared.error()
            }
        }
    }

    @ViewBuilder
    func viewWithViewModel(viewModel: ConcertsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let concertToday = viewModel.concertToday {
                    Color.clear
                        .frame(height: fullSizeTodaysConcert ? 200 : 60)
                }

                if !viewModel.futureConcerts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(TextKey.homeUpcomingConcerts.localized)
                            .font(.cjTitle)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(viewModel.futureConcerts) { visit in
                                    Button {
                                        HapticManager.shared.impact(.light)
                                        navigationManager.push(.concertDetail(visit))
                                    } label: {
                                        FutureConcertView(concert: visit)
                                    }
                                    .buttonStyle(CardButtonStyle())
                                    .contextMenu {
                                        Button {
                                            HapticManager.shared.impact(.light)
                                            navigationManager.push(.concertDetail(visit))
                                        } label: {
                                            Label(TextKey.sectionDetailPage.localized, systemImage: "info.circle")
                                        }
                                        .font(.cjBody)

                                        Divider()

                                        Button(role: .destructive) {
                                            HapticManager.shared.impact(.medium)
                                            concertToDelete = visit
                                        } label: {
                                            Label(TextKey.delete.localized, systemImage: "trash")
                                        }
                                        .font(.cjBody)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollClipDisabled()
                    }
                }

                if !viewModel.pastConcerts.isEmpty {
                    Text(TextKey.homePastConcerts.localized)
                        .font(.cjTitle)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                
                ForEach(viewModel.pastConcerts.enumerated().map({ $0 }), id: \.element.id) { index, visit in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(visit.title ?? visit.artist.name)
                            .font(.cjCaption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        Button {
                            HapticManager.shared.impact(.light)
                            navigationManager.push(.concertDetail(visit))
                        } label: {
                            PastConcertView(concert: visit)
                        }
                        .buttonStyle(CardButtonStyle())
                        .contextMenu {
                            Button {
                                HapticManager.shared.impact(.light)
                                navigationManager.push(.concertDetail(visit))
                            } label: {
                                Label(TextKey.sectionDetailPage.localized, systemImage: "info.circle")
                            }
                            .font(.cjBody)

                            Divider()

                            Button(role: .destructive) {
                                HapticManager.shared.impact(.medium)
                                concertToDelete = visit
                            } label: {
                                Label(TextKey.delete.localized, systemImage: "trash")
                            }
                            .font(.cjBody)
                        }
                        .padding(.horizontal, 20)
                    }

                    if index != 0, index % 5 == 0 {
                        AdaptiveBannerAdView()
                            .padding(.vertical, 8)
                    }
                }

                if viewModel.pastConcerts.count < 5 {
                    AdaptiveBannerAdView()
                        .padding(.horizontal, 20)
                }
            }
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo
                                .frame(in: .named(ScrollOffsetNamespace.namespace))
                                .minY
                        )
                }
                .frame(height: 1)
            }
            .padding(.vertical, 20)
        }
        .coordinateSpace(name: ScrollOffsetNamespace.namespace)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                fullSizeTodaysConcert = value > 10
//                if fullSizeTodaysConcert {
//                    HapticManager.shared.impact(.light)
//                }
            }
        }
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            createButton()
        }
        .refreshable {
            await viewModel.refreshConcerts()
        }
        .overlay(alignment: .top) {
            if let concertToday = viewModel.concertToday {
                Button {
                    HapticManager.shared.impact(.medium)
                    navigationManager.push(.concertDetail(concertToday))
                } label: {
                    ConcertTodayView(concert: concertToday, fullSizeTodaysConcert: $fullSizeTodaysConcert)
                }
                .buttonStyle(CardButtonStyle())
                .contextMenu {
                    Button {
                        HapticManager.shared.impact(.light)
                        navigationManager.push(.concertDetail(concertToday))
                    } label: {
                        Label(TextKey.sectionDetailPage.localized, systemImage: "info.circle")
                    }
                    .font(.cjBody)

                    Divider()

                    Button(role: .destructive) {
                        HapticManager.shared.impact(.medium)
                        concertToDelete = concertToday
                    } label: {
                        Label(TextKey.delete.localized, systemImage: "trash")
                    }
                    .font(.cjBody)
                }
            }

        }
        .adaptiveSheet(item: $concertToDelete) { item in
            @State var loading: Bool = false

            VStack(spacing: 20) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text(TextKey.concertDelete.localized)
                    .font(.cjTitle)

                let concertText = item.title == nil ? "das Konzert" : "\"\(item.title!)\""
                Text(TextKey.concertDeleteQuestion.localized(with: concertText))
                    .font(.cjBody)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        HapticManager.shared.impact(.heavy)
                        Task {
                            loading = true
                            await viewModel.deleteConcert(item)
                            concertToDelete = nil
                            loading = false
                            HapticManager.shared.success()
                        }
                    } label: {
                        if loading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(TextKey.delete.localized)
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
                        concertToDelete = nil
                    } label: {
                        Text(TextKey.cancel.localized)
                            .font(.cjHeadline)
                    }
                    .buttonStyle(ModernButtonStyle(style: .glass, color: dependencies.colorThemeManager.appTint))
                }
            }
            .padding(24)
            .sheet(item: $confirmationText) { item in
                ConfirmationView(message: item)
            }
        }
    }

    @ViewBuilder
    func createButton() -> some View {
        HStack {
            Spacer()
            Button {
                HapticManager.shared.impact(.medium)
                chooseCreateFlowPresenting = true
            } label: {
                ZStack {
                    Circle()
                        .fill(dependencies.colorThemeManager.appTint)
                        .frame(width: 60, height: 60)
                        .shadow(color: dependencies.colorThemeManager.appTint.opacity(0.4), radius: 12, x: 0, y: 6)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(FloatingButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func navigationDestination(for route: NavigationRoute) -> some View {
        switch route {
        case .createConcert:
            CreateConcertVisitView()
                .toolbarVisibility(.hidden, for: .tabBar)

        case .ticketScan:
            TicketScannerView()
                .toolbarVisibility(.hidden, for: .tabBar)

        case .createConcertFromTicket(let ticketInfo):
            CreateConcertVisitView(ticketInfo: ticketInfo)
                .toolbarVisibility(.hidden, for: .tabBar)

        case .createConcertFromImport(let importedConcert):
            CreateConcertVisitView(importedConcert: importedConcert)
                .toolbarVisibility(.hidden, for: .tabBar)

        case .concertDetail(let concert):
            ConcertDetailView(concert: concert)
                .toolbarVisibility(.hidden, for: .tabBar)

        case .colorPicker:
            ColorSetView()
                .toolbarVisibility(.hidden, for: .tabBar)

        case .faq:
            FAQView()
                .toolbarVisibility(.hidden, for: .tabBar)

        case .profile:
            ProfileView()
                .toolbarVisibility(.hidden, for: .tabBar)

        case .artistDetail(let artist):
            ArtistDetailView(artist: artist)
                .toolbarVisibility(.hidden, for: .tabBar)
        default:
            Text("Not implemented: \(String(describing: route))")
        }
    }

    private func refreshVisits() async {
        await viewModel?.loadConcerts()
    }
}
