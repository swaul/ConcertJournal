//
//  ConcertsView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.12.25.
//

import SwiftUI

struct ConcertsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager

    @State private var viewModel: ConcertsViewModel? = nil
    
    @State private var chooseCreateFlowPresenting: Bool = false

    var body: some View {
        @Bindable var navigationManager = navigationManager

        NavigationStack(path: $navigationManager.path) {
            Group {
                if let viewModel, !viewModel.isLoading {
                    if let errorMessage = viewModel.errorMessage {
                        VStack {
                            Text(errorMessage)
                            Button {
                                Task {
                                    await viewModel.refreshConcerts()
                                }
                            } label: {
                                Label("Neu laden", systemImage: "arrow.counterclockwise")
                                    .font(.cjHeadline)
                            }
                            .buttonStyle(.glassProminent)
                        }
                    } else if viewModel.futureConcerts.isEmpty && viewModel.pastConcerts.isEmpty {
                        Button {
                            navigationManager.push(.createConcert)
                        } label: {
                            Label("Neues Konzert hinzufügen", systemImage: "plus.circle.fill")
                                .font(.cjHeadline)
                        }
                        .buttonStyle(.glassProminent)
                    } else {
                        viewWithViewModel(viewModel: viewModel)
                    }
                } else {
                    LoadingView()
                }
            }
            .task {
                if viewModel == nil {
                    guard let userId = dependencies.supabaseClient.currentUserId?.uuidString else {
                        return
                    }

                    // ViewModel wird mit Dependencies aus Container erstellt
                    viewModel = ConcertsViewModel(
                        concertRepository: dependencies.concertRepository,
                        userManager: dependencies.userSessionManager,
                        userId: userId
                    )

                    // Daten laden
                    await viewModel?.loadConcerts()
                }
            }
            .sheet(isPresented: $chooseCreateFlowPresenting) {
                VStack {
                    Text("Wie möchtest du dein Konzert erstellen?")
                        .font(.cjTitle)
                        .padding()
                    
                    Spacer()
                    
                    Button {
                        chooseCreateFlowPresenting = false
                        navigationManager.push(.createConcert)
                    } label: {
                        Label("Manuell erstellen", systemImage: "long.text.page.and.pencil")
                            .frame(maxWidth: .infinity)
                            .font(.cjTitle2)
                            .padding(4)
                    }
                    .buttonStyle(.glass)
                    .padding()
                    
                    Button {
                        chooseCreateFlowPresenting = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            navigationManager.push(.ticketScan)
                        }
                    } label: {
                        Label("Mit Ticket Foto erstellen", systemImage: "document.viewfinder")
                            .frame(maxWidth: .infinity)
                            .font(.cjTitle2)
                            .padding(4)
                    }
                    .buttonStyle(.glass)
                    .padding()
                    
                    Spacer()
                }
                .padding(.top)
                .presentationDetents([.medium])
            }
            .navigationTitle("Concerts")
            .navigationDestination(for: NavigationRoute.self) { route in
                navigationDestination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigationManager.push(.profile)
                    } label: {
                        Image(systemName: "person")
                    }
                }
            }
        }
        .onReceive(dependencies.userSessionManager.userSessionChanged) { user in
            if user == nil {
                navigationManager.popToRoot()
            }
        }
    }

    @ViewBuilder
    func viewWithViewModel(viewModel: ConcertsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !viewModel.futureConcerts.isEmpty {
                    Text("Deine nächsten Konzerte")
                        .font(.cjTitle)
                        .padding(.vertical)

                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 16) {
                            ForEach(viewModel.futureConcerts) { visit in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(visit.date.dateOnlyString)
                                        .fontPlayfairSCRegular(16)
                                        .padding(2)
                                        .glassEffect()
                                    Button {
                                        navigationManager.push(.concertDetail(visit))
                                    } label: {
                                        futureConcert(concert: visit)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }
                    }
                    .scrollTargetBehavior(.viewAligned(anchor: .leading))
                    .scrollClipDisabled()
                    .scrollIndicators(.hidden)

                    Text("Vergangene Konzerte")
                        .font(.cjTitle)
                        .padding(.vertical)
                }
                ForEach(viewModel.pastConcerts) { visit in
                    Section {
                        Button {
                            navigationManager.push(.concertDetail(visit))
                        } label: {
                            visitItem(visit: visit)
                        }
                    } header: {
                        Text(visit.title ?? visit.artist.name)
                            .font(.cjCaption)
                    }
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            createButton()
        }
        .refreshable {
            await viewModel.refreshConcerts()
        }
    }

    @ViewBuilder
    func visitItem(visit: FullConcertVisit) -> some View {
        HStack(spacing: 0) {
            Group {
                AsyncImage(url: URL(string: visit.artist.imageUrl ?? "")) { result in
                    switch result {
                    case .empty:
                        Color.gray
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        dependencies.colorThemeManager.appTint
                    @unknown default:
                        Color.blue
                    }
                }
            }
            .frame(width: 100, height: 100)
        
            VStack(alignment: .leading) {
                MarqueeText(visit.artist.name, font: .cjTitle)
                    .foregroundStyle(.white)
                    .frame(height: 30)
                if let venue = visit.venue {
                    Text(venue.name)
                        .font(.cjBody)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                }
                if let city = visit.city {
                    Text(city)
                        .font(.cjBody)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                }
            }
            Spacer()
        }
        .compositingGroup()
        .background {
            dependencies.colorThemeManager.appTint.opacity(0.4)
        }
        .cornerRadius(20)
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 100)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: UIColor.systemBackground))
                .shadow(radius: 3, x: 2, y: 2)
        }
    }

    @ViewBuilder
    func futureConcert(concert: FullConcertVisit) -> some View {
        HStack {
            Group {
                AsyncImage(url: URL(string: concert.artist.imageUrl ?? "")) { result in
                    switch result {
                    case .empty:
                        Color.gray
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.red
                    @unknown default:
                        Color.blue
                    }
                }
            }
            .frame(width: 100, height: 100)
        
            VStack(alignment: .leading) {
                Text(concert.artist.name)
                    .lineLimit(nil)
                    .font(.cjTitle2)
                    .foregroundStyle(.white)
                if let venue = concert.venue {
                    Text(venue.name)
                        .font(.cjBody)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let city = concert.city {
                    Text(city)
                        .font(.cjBody)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background {
            dependencies.colorThemeManager.appTint.opacity(0.4)
        }
        .cornerRadius(20)
        .frame(height: 100)
    }

    @ViewBuilder
    func createButton() -> some View {
        HStack {
            Spacer()
                Button {
                    chooseCreateFlowPresenting = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                        .padding(8)
                }
                .buttonStyle(.glassProminent)
        }
        .padding()
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

        default:
            Text("Not implemented: \(String(describing: route))")
        }
    }

    private func refreshVisits() async {
        await viewModel?.loadConcerts()
    }

}
