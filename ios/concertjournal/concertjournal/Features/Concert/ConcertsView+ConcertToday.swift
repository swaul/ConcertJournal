//
//  ConcertsView+ConcertToday.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import Combine
import SwiftUI

struct ConcertTodayView: View {

    @Environment(\.dependencies) var dependencies

    let concert: Concert

    @Binding var fullSizeTodaysConcert: Bool

    @Namespace private var todaysConcert

    @State private var isViewVisible = false
    @State private var timeRemaining: Int? = nil
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body:  some View {
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
                                .matchedGeometryEffect(id: "clock.fill", in: todaysConcert)
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
                                .matchedGeometryEffect(id: "progressView", in: todaysConcert)
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
                                    .matchedGeometryEffect(id: "placeHolder", in: todaysConcert)
                            }
                        @unknown default:
                            Color.gray
                                .matchedGeometryEffect(id: "placeHolder", in: todaysConcert)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .matchedGeometryEffect(id: "imageContainer", in: todaysConcert, anchor: .center)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(concert.title ?? concert.artist.name)
                            .font(.cjHeadline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .matchedGeometryEffect(id: "title", in: todaysConcert, anchor: .topLeading)

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
                                .matchedGeometryEffect(id: "progressView", in: todaysConcert)
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
                                    .matchedGeometryEffect(id: "placeHolder", in: todaysConcert)
                            }
                        @unknown default:
                            Color.gray
                                .matchedGeometryEffect(id: "placeHolder", in: todaysConcert)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .matchedGeometryEffect(id: "imageContainer", in: todaysConcert, anchor: .center)

                    Text(concert.title ?? concert.artist.name)
                        .font(.cjHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .matchedGeometryEffect(id: "title", in: todaysConcert, anchor: .topLeading)

                    if let timeRemaining, timeRemaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .matchedGeometryEffect(id: "clock.fill", in: todaysConcert)
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
}
