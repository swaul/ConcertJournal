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
    @AppStorage("timerVibrationOn") private var timerVibrationOn = true

    @State private var timeRemaining: Int? = nil
    @State private var isViewVisible = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var viewModel: ConcertsViewModel? = nil

    @State private var chooseCreateFlowPresenting: Bool = false
    @State private var concertToDelete: PartialConcertVisit? = nil
    @State private var confirmationText: ConfirmationMessage? = nil

    @Namespace private var todaysConcert

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
                                Label("Neu laden", systemImage: "arrow.counterclockwise")
                                    .font(.cjHeadline)
                            }
                            .buttonStyle(ModernButtonStyle(style: .prominent,
                                                           color: dependencies.colorThemeManager.appTint))
                        }
                        .padding()
                    } else if viewModel.futureConcerts.isEmpty && viewModel.pastConcerts.isEmpty {
                        VStack(spacing: 24) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 80))
                                .foregroundStyle(dependencies.colorThemeManager.appTint.opacity(0.6))

                            Text("Noch keine Konzerte")
                                .font(.cjTitle)

                            Text("Füge dein erstes Konzert hinzu und starte deine Musikreise!")
                                .font(.cjBody)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Button {
                                HapticManager.shared.impact(.medium)
                                navigationManager.push(.createConcert)
                            } label: {
                                Label("Erstes Konzert hinzufügen", systemImage: "plus.circle.fill")
                                    .font(.cjHeadline)
                            }
                            .buttonStyle(ModernButtonStyle(style: .prominent, color: dependencies.colorThemeManager.appTint))
                        }
                        .padding()
                    } else {
                        viewWithViewModel(viewModel: viewModel)
                    }
                } else {
                    LoadingView()
                }
            }
            .background(Color("backgroundColor"))
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
                VStack(spacing: 20) {
                    Text("Wie möchtest du dein Konzert erstellen?")
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
                                Text("Manuell erstellen")
                                    .font(.cjHeadline)
                                Text("Alle Details selbst eingeben")
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
                                    Text("Mit Ticket erstellen")
                                        .font(.cjHeadline)
                                    Text("Ticket scannen und automatisch befüllen")
                                        .font(.cjCaption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.glass)

                        Text("BETA")
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
                        Text("Deine nächsten Konzerte")
                            .font(.cjTitle)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(viewModel.futureConcerts) { visit in
                                    Button {
                                        HapticManager.shared.impact(.light)
                                        navigationManager.push(.concertDetail(visit))
                                    } label: {
                                        futureConcert(concert: visit)
                                    }
                                    .buttonStyle(CardButtonStyle())
                                    .contextMenu {
                                        Button {
                                            HapticManager.shared.impact(.light)
                                            navigationManager.push(.concertDetail(visit))
                                        } label: {
                                            Label("Detail Seite", systemImage: "info.circle")
                                        }
                                        .font(.cjBody)

                                        Divider()

                                        Button(role: .destructive) {
                                            HapticManager.shared.impact(.medium)
                                            concertToDelete = visit
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
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

                    Text("Vergangene Konzerte")
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
                            visitItem(visit: visit)
                        }
                        .buttonStyle(CardButtonStyle())
                        .contextMenu {
                            Button {
                                HapticManager.shared.impact(.light)
                                navigationManager.push(.concertDetail(visit))
                            } label: {
                                Label("Detail Seite", systemImage: "info.circle")
                            }
                            .font(.cjBody)

                            Divider()

                            Button(role: .destructive) {
                                HapticManager.shared.impact(.medium)
                                concertToDelete = visit
                            } label: {
                                Label("Löschen", systemImage: "trash")
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
                if fullSizeTodaysConcert {
                    HapticManager.shared.impact(.light)
                }
            }
        }
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            createButton()
        }
        .refreshable {
            HapticManager.shared.impact(.light)
            await viewModel.refreshConcerts()
            HapticManager.shared.success()
        }
        .overlay(alignment: .top) {
            if let concertToday = viewModel.concertToday {
                Button {
                    HapticManager.shared.impact(.medium)
                    navigationManager.push(.concertDetail(concertToday))
                } label: {
                    makeConcertTodayView(concert: concertToday)
                }
                .buttonStyle(CardButtonStyle())
                .contextMenu {
                    Button {
                        HapticManager.shared.impact(.light)
                        navigationManager.push(.concertDetail(concertToday))
                    } label: {
                        Label("Detail Seite", systemImage: "info.circle")
                    }
                    .font(.cjBody)

                    Button {
                        HapticManager.shared.impact(.light)
                        timerVibrationOn.toggle()
                    } label: {
                        Label(timerVibrationOn ? "Vibration deaktivieren" : "Vibration aktivieren",
                              systemImage: timerVibrationOn ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .font(.cjBody)

                    Divider()

                    Button(role: .destructive) {
                        HapticManager.shared.impact(.medium)
                        concertToDelete = concertToday
                    } label: {
                        Label("Löschen", systemImage: "trash")
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

                Text("Konzert löschen?")
                    .font(.cjTitle)

                let concertText = item.title == nil ? "das Konzert" : "\"\(item.title!)\""
                Text("Möchtest du \(concertText) wirklich löschen? Das kann nicht rückgängig gemacht werden.")
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
                            Text("Löschen")
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
                        Text("Abbrechen")
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

    func secondsToHoursMinutesSeconds(_ seconds: Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }

    func secondsToHoursMinutesSeconds(_ seconds: Int) -> String {
        let (h, m, s) = secondsToHoursMinutesSeconds(seconds)

        let hours = String(format: "%02d", h)
        let minutes = String(format: "%02d", m)
        let seconds = String(format: "%02d", s)

        if h == 0, m == 0 {
            return "noch \(seconds) Sek!"
        } else if h == 0 {
            return "\(minutes):\(seconds)"
        }

        return "\(hours):\(minutes):\(seconds)"
    }

    @State var fullSizeTodaysConcert = true

    @ViewBuilder
    func makeConcertTodayView(concert: PartialConcertVisit) -> some View {
        VStack(spacing: 16) {
            if fullSizeTodaysConcert {
                // Header mit Badge und Timer
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                        Text("Heute")
                            .font(.cjHeadline)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(dependencies.colorThemeManager.appTint)
                    .cornerRadius(20)

                    Spacer()

                    if let timeRemaining, timeRemaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text(secondsToHoursMinutesSeconds(timeRemaining))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(countsDown: true))
                                .matchedGeometryEffect(id: "timerText", in: todaysConcert)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: dependencies.colorThemeManager.appTint.opacity(0.5), radius: 8)
                        .matchedGeometryEffect(id: "timer", in: todaysConcert)
                    }
                }

                // Konzert Info Card
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: concert.artist.imageUrl ?? "")) { result in
                        switch result {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            ZStack {
                                dependencies.colorThemeManager.appTint.opacity(0.3)
                                Image(systemName: "music.note")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        @unknown default:
                            Color.gray
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .matchedGeometryEffect(id: "image", in: todaysConcert)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(concert.title ?? concert.artist.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .matchedGeometryEffect(id: "title", in: todaysConcert)

                        if let venue = concert.venue {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption)
                                Text(venue.name)
                                    .font(.cjBody)
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        }

                        if let city = concert.city {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.caption)
                                Text(city)
                                    .font(.cjBody)
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        }
                    }

                    Spacer()
                }
            } else {
                HStack {
                    AsyncImage(url: URL(string: concert.artist.imageUrl ?? "")) { result in
                        switch result {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            ZStack {
                                dependencies.colorThemeManager.appTint.opacity(0.3)
                                Image(systemName: "music.note")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        @unknown default:
                            Color.gray
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .matchedGeometryEffect(id: "image", in: todaysConcert)

                    Text(concert.title ?? concert.artist.name)
                        .font(.cjCaption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: "title", in: todaysConcert)

                    if let timeRemaining, timeRemaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text(secondsToHoursMinutesSeconds(timeRemaining))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(countsDown: true))
                                .matchedGeometryEffect(id: "timerText", in: todaysConcert)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: dependencies.colorThemeManager.appTint.opacity(0.5), radius: 8)
                        .matchedGeometryEffect(id: "timer", in: todaysConcert)
                    }
                }
            }
        }
        .padding(20)
        .background {
            ZStack {
                Color.black

                // Gradient Background
                LinearGradient(
                    colors: [
                        dependencies.colorThemeManager.appTint,
                        dependencies.colorThemeManager.appTint.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Animated glow effect
                if let timeRemaining, timeRemaining > 0, timeRemaining < 3600 {
                    Circle()
                        .fill(dependencies.colorThemeManager.appTint.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: 100, y: -50)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: timeRemaining)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: dependencies.colorThemeManager.appTint.opacity(0.4), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
        .onReceive(timer) { time in
            guard let timeRemaining, isViewVisible else { return }
            if timeRemaining > 0 {
                withAnimation(.spring(response: 0.3)) {
                    self.timeRemaining! -= 1
                    if timerVibrationOn, timeRemaining % 60 == 0 {
                        HapticManager.shared.impact(.light)
                    }
                }
            }
        }
        .onAppear {
            guard let openingTime = concert.openingTime else { return }
            timeRemaining = Int(openingTime.timeIntervalSince(.now))
            isViewVisible = true
        }
        .onDisappear {
            isViewVisible = false
        }
        .frame(maxHeight: fullSizeTodaysConcert ? 200 : 60)
    }

    @ViewBuilder
    func visitItem(visit: PartialConcertVisit) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: visit.artist.imageUrl ?? "")) { result in
                switch result {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        dependencies.colorThemeManager.appTint.opacity(0.3)
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                @unknown default:
                    Color.gray
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                MarqueeText(visit.artist.name, font: .cjTitle2)
                    .foregroundStyle(.primary)
                    .frame(height: 24)

                if let venue = visit.venue {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.caption)
                        Text(venue.name)
                            .font(.cjBody)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                if let city = visit.city {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.caption)
                        Text(city)
                            .font(.cjBody)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    @ViewBuilder
    func futureConcert(concert: PartialConcertVisit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with overlay
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: concert.artist.imageUrl ?? "")) { result in
                    switch result {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        ZStack {
                            dependencies.colorThemeManager.appTint.opacity(0.3)
                            Image(systemName: "music.note")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    @unknown default:
                        Color.gray
                    }
                }
                .frame(width: 280, height: 180)
                .clipped()

                // Date Badge
                Text(concert.date.dateOnlyString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(12)
            }

            // Info Section
            VStack(alignment: .leading, spacing: 8) {
                Text(concert.artist.name)
                    .font(.cjTitle2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let venue = concert.venue {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(venue.name)
                            .font(.cjCaption)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                if let city = concert.city {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2.fill")
                            .font(.caption)
                        Text(city)
                            .font(.cjCaption)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 280)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
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

// MARK: - Custom Button Styles

struct ModernButtonStyle: ButtonStyle {
    enum Style {
        case prominent
        case glass
    }

    let style: Style
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background {
                if style == .prominent {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
            }
            .foregroundStyle(style == .prominent ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.15), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .brightness(configuration.isPressed ? -0.05 : 0)
    }
}

struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.2 : 0.3), radius: configuration.isPressed ? 8 : 16, x: 0, y: configuration.isPressed ? 4 : 8)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
