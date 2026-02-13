//
//  ConcertsView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 30.12.25.
//

import SwiftUI
import Combine

struct ConcertsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.navigationManager) private var navigationManager

    @State private var viewModel: ConcertsViewModel? = nil

    @State private var chooseCreateFlowPresenting: Bool = false
    @State private var concertToDelete: PartialConcertVisit? = nil
    @State private var confirmationText: ConfirmationMessage? = nil

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
                        .padding()
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

                    viewModel = ConcertsViewModel(
                        concertRepository: dependencies.concertRepository,
                        userManager: dependencies.userSessionManager,
                        userId: userId
                    )
                }
            }
            .adaptiveSheet(isPresent: $chooseCreateFlowPresenting) {
                VStack(spacing: 16) {
                    Text("Wie möchtest du dein Konzert erstellen?")
                        .font(.cjTitle)
                        .padding()
                        .padding(.bottom)

                    Button {
                        chooseCreateFlowPresenting = false
                        navigationManager.push(.createConcert)
                    } label: {
                        Label("Manuell erstellen", systemImage: "long.text.page.and.pencil")
                            .frame(maxWidth: .infinity)
                            .font(.cjHeadline)
                            .padding(4)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal)

                    ZStack(alignment: .topTrailing) {
                        Button {
                            chooseCreateFlowPresenting = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                navigationManager.push(.ticketScan)
                            }
                        } label: {
                            Label("Mit Ticket Foto erstellen", systemImage: "document.viewfinder")
                                .frame(maxWidth: .infinity)
                                .font(.cjHeadline)
                                .padding(4)
                        }
                        .buttonStyle(.glass)

                        Text("BETA")
                            .font(.cjCaption)
                            .foregroundStyle(dependencies.colorThemeManager.appTint)
                            .padding(4)
                            .background { dependencies.colorThemeManager.appTint.opacity(0.2) }
                            .clipShape(Capsule())
                            .offset(y: -10)
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
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
                if let concertToday = viewModel.concertToday {
                    Button {
                        navigationManager.push(.concertDetail(concertToday))
                    } label: {
                        makeConcertTodayView(concert: concertToday)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Detail Seite für \(concertToday.title ?? "Konzert")") {
                            navigationManager.push(.concertDetail(concertToday))
                        }
                        .font(.cjBody)
                        Button("\(concertToday.title ?? "Konzert") löschen", role: .destructive) {
                            concertToDelete = concertToday
                        }
                        .font(.cjBody)
                    }
                }

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
                                    .contextMenu {
                                        Button("Detail Seite für \(visit.title ?? "Konzert")") {
                                            navigationManager.push(.concertDetail(visit))
                                        }
                                        .font(.cjBody)
                                        Button("\(visit.title ?? "Konzert") löschen", role: .destructive) {
                                            concertToDelete = visit
                                        }
                                        .font(.cjBody)
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
                ForEach(viewModel.pastConcerts.enumerated(), id: \.element) { index, visit in
                    Section {
                        Button {
                            navigationManager.push(.concertDetail(visit))
                        } label: {
                            visitItem(visit: visit)
                        }
                        .contextMenu {
                            Button("Detail Seite für \(visit.title ?? "Konzert")") {
                                navigationManager.push(.concertDetail(visit))
                            }
                            .font(.cjBody)
                            Button("\(visit.title ?? "Konzert") löschen", role: .destructive) {
                                concertToDelete = visit
                            }
                            .font(.cjBody)
                        }
                    } header: {
                        Text(visit.title ?? visit.artist.name)
                            .font(.cjCaption)
                    }
                    if index != 0, index % 5 == 0 {
                        AdaptiveBannerAdView()
                    }
                }

                if viewModel.pastConcerts.count < 5 {
                    AdaptiveBannerAdView()
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
        .adaptiveSheet(item: $concertToDelete) { item in
            @State var loading: Bool = false

            VStack(spacing: 16) {
                Text("Konzert löschen?")
                    .font(.cjTitle)
                    .padding(.top)

                let concertText = item.title == nil ? "das Konzert" : "\"\(item.title!)\""
                Text("Möchtest du \(concertText) wirklich löschen? Das kann nicht Rückgängig gemacht werden.")
                    .font(.cjBody)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .padding(.vertical)

                Button(role: .destructive) {
                    Task {
                        loading = true
                        await viewModel.deleteConcert(item)
                        concertToDelete = nil
                        loading = false
                    }
                } label: {
                    Text("Löschen")
                        .font(.cjHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(4)
                }
                .buttonStyle(.glassProminent)

                Button {
                    concertToDelete = nil
                } label: {
                    Text("Abbrechen")
                        .font(.cjHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(4)
                }
                .buttonStyle(.glass)
            }
            .padding()
        }
        .sheet(item: $confirmationText) { item in
            ConfirmationView(message: item)
        }
    }

    @State private var timeRemaining: Int? = nil
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func secondsToHoursMinutesSeconds(_ seconds: Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }

    func secondsToHoursMinutesSeconds(_ seconds: Int) -> String {
        let (h, m, s) = secondsToHoursMinutesSeconds(seconds)
        return "\(h):\(m):\(s)"
    }

    @ViewBuilder
    func makeConcertTodayView(concert: PartialConcertVisit) -> some View {
        VStack {
            HStack {
                Text("Heutiges Konzert:")
                    .font(.cjTitleF)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let timeRemaining {
                    Text(secondsToHoursMinutesSeconds(timeRemaining))
                        .font(.cjTitle)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
            }
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
                            dependencies.colorThemeManager.appTint
                        @unknown default:
                            Color.blue
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading) {
                    Text(concert.title ?? concert.artist.name)
                        .foregroundStyle(.white)
                        .font(.cjTitle2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let venue = concert.venue {
                        Text(venue.name)
                            .font(.cjBody)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                    }
                    if let city = concert.city {
                        Text(city)
                            .font(.cjBody)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                    }
                }
            }
            .padding()
            .compositingGroup()
            .background {
                dependencies.colorThemeManager.appTint.opacity(0.4)
            }
            .cornerRadius(20)
            .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 100)
            .onReceive(timer) { time in
                guard let timeRemaining else { return }
                if timeRemaining > 0 {
                    withAnimation {
                        self.timeRemaining! -= 1
                    }
                }
            }
        }
        .onAppear {
            guard let openingTime = concert.openingTime else { return }
            timeRemaining = Int(openingTime.timeIntervalSince(.now))
        }
    }

    @ViewBuilder
    func visitItem(visit: PartialConcertVisit) -> some View {
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
    func futureConcert(concert: PartialConcertVisit) -> some View {
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
