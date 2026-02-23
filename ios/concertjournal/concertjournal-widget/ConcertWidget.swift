//
//  ConcertWidget.swift
//  concertjournal
//
//  Created by Paul Kühnel on 22.02.26.
//

import WidgetKit
import SwiftUI
import CoreData

// MARK: - CoreData Stack (shared with main app via App Group)

private let appGroupID = "group.de.kuehnel.concertjournal" // ← anpassen

private var sharedContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "CJModels")
    let storeURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
        .appendingPathComponent("CJModels.sqlite")

    let description = NSPersistentStoreDescription(url: storeURL)
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { _, error in
        if let error { print("Widget CoreData error: \(error)") }
    }
    return container
}()

// MARK: - Models

struct ConcertEntry: TimelineEntry {
    let date: Date
    let today: WidgetConcert?
    let next: WidgetConcert?
    let last: WidgetConcert?
    let appTint: Color
}

struct WidgetConcert: Equatable {
    let title: String
    let artistName: String
    let artistImageData: Data?
    let venueName: String?
    let city: String?
    let date: Date
    let openingTime: Date?
    let rating: Int?
}

private func loadImageData(from urlString: String?) -> Data? {
    guard let urlString,
          let url = URL(string: urlString),
          let data = try? Data(contentsOf: url) // synchron, ok im Widget-Context
    else { return nil }
    return data
}

// Oben in ConcertWidget.swift, nach appGroupID
private func loadAppTint() -> Color {
    guard let defaults = UserDefaults(suiteName: appGroupID),
          let data = defaults.data(forKey: "AppTintColorRGBA"),
          let rgba = try? JSONDecoder().decode(RGBAColor.self, from: data)
    else {
        return .purple // Fallback
    }
    return Color(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
}

// Den gleichen Codable Struct wie im ColorThemeManager
private struct RGBAColor: Codable {
    var r, g, b, a: CGFloat
}

// MARK: - CoreData Fetcher

private func fetchConcerts() -> (today: WidgetConcert?, next: WidgetConcert?, last: WidgetConcert?) {
    let context = sharedContainer.viewContext
    let request = NSFetchRequest<NSManagedObject>(entityName: "Concert")
    request.predicate = NSPredicate(format: "syncStatus != %@", "deleted")

    guard let results = try? context.fetch(request) else {
        return (nil, nil, nil)
    }

    let now = Date()
    let calendar = Calendar.current

    // Map zu WidgetConcert
    let all: [(date: Date, concert: WidgetConcert)] = results.compactMap { obj in
        guard let date = obj.value(forKey: "date") as? Date else { return nil }
        let artistObj = obj.value(forKey: "artist") as? NSManagedObject
        let venueObj = obj.value(forKey: "venue") as? NSManagedObject

        let concert = WidgetConcert(
            title: obj.value(forKey: "title") as? String ?? "",
            artistName: artistObj?.value(forKey: "name") as? String ?? "Unbekannt",
            artistImageData: loadImageData(from: artistObj?.value(forKey: "imageUrl") as? String),
            venueName: venueObj?.value(forKey: "name") as? String,
            city: obj.value(forKey: "city") as? String,
            date: date,
            openingTime: obj.value(forKey: "openingTime") as? Date,
            rating: (obj.value(forKey: "rating") as? Int16).map { Int($0) }
        )
        return (date, concert)
    }.sorted { $0.date < $1.date }

    let todayItems = all.filter { calendar.isDateInToday($0.date) }
    let futureItems = all.filter { $0.date > now && !calendar.isDateInToday($0.date) }
    let pastItems = all.filter { $0.date < now && !calendar.isDateInToday($0.date) }

    return (
        today: todayItems.first?.concert,
        next: futureItems.first?.concert,
        last: pastItems.last?.concert
    )
}

// MARK: - Provider

struct ConcertProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConcertEntry {
        ConcertEntry(
            date: Date(),
            today: WidgetConcert(title: "Rock am Ring", artistName: "Rammstein", artistImageData: nil, venueName: "Nürburgring", city: "Nürburg", date: Date(), openingTime: Date(), rating: nil),
            next: WidgetConcert(title: "Tour 2026", artistName: "The Weeknd", artistImageData: nil, venueName: "Olympiastadion", city: "München", date: Date().addingTimeInterval(86400 * 3), openingTime: Date(), rating: nil),
            last: WidgetConcert(title: "Eras Tour", artistName: "Taylor Swift", artistImageData: nil, venueName: "Volksparkstadion", city: "Hamburg", date: Date().addingTimeInterval(-86400 * 7), openingTime: Date(), rating: 9),
            appTint: .accentColor
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ConcertEntry) -> Void) {
        let (today, next, last) = fetchConcerts()
        completion(ConcertEntry(date: Date(), today: today, next: next, last: last, appTint: loadAppTint()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConcertEntry>) -> Void) {
        let (today, next, last) = fetchConcerts()
        let entry = ConcertEntry(date: Date(), today: today, next: next, last: last, appTint: loadAppTint())
        // Refresh täglich um Mitternacht
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct ConcertWidgetEntryView: View {
    var entry: ConcertEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small: Nur heute oder nächstes

struct SmallWidgetView: View {
    let entry: ConcertEntry

    var displayConcert: WidgetConcert? { entry.today ?? entry.next }
    var isToday: Bool { entry.today != nil }

    var body: some View {
        ZStack {
            // Background Image
            if let data = displayConcert?.artistImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
            } else {
                Color.black
                    .overlay(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.indigo.opacity(0.4)],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                // Badge
                HStack {
                    Text(isToday ? "HEUTE" : "NÄCHSTES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isToday ? entry.appTint.opacity(0.8) : Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    Spacer()
                }

                Spacer()

                if let concert = displayConcert {
                    Text(concert.artistName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if isToday {
                        Text(concert.date.widgetTimeString)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text(concert.date.widgetDateString)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let venue = concert.venueName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 9))
                            Text(venue)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    }
                } else {
                    Text("Kein Konzert\ngeplant")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Medium: Heute + Nächstes oder Letztes

struct MediumWidgetView: View {
    let entry: ConcertEntry

    var body: some View {
        HStack(spacing: 0) {
            let main = entry.today ?? entry.next
            let isToday = entry.today != nil

            MediumMainCard(concert: main, isToday: isToday, tint: entry.appTint)
                .frame(maxWidth: .infinity)
                .clipped()  // ← neu

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 12)

            let secondary = main == entry.next ? entry.last : entry.next
            let secondaryLabel = entry.next != nil ? "NÄCHSTES" : "LETZTES"
            MediumSecondaryCard(concert: secondary, label: secondaryLabel, tint: entry.appTint)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // ← Widget-Größe nutzen, nicht mehr
    }
}

struct MediumMainCard: View {
    let concert: WidgetConcert?
    let isToday: Bool
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = concert?.artistImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.75), .black.opacity(0.2)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
            } else {
                gradientPlaceholder
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isToday ? "HEUTE" : "NÄCHSTES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isToday ? tint.opacity(0.8) : Color.white.opacity(0.25))
                    .clipShape(Capsule())

                if let concert {
                    Text(concert.artistName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if isToday, let openingTime = concert.openingTime {
                        Text(openingTime.widgetTimeString)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text(concert.date.widgetDateString)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else {
                    Text("Kein Konzert")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(12)
            .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(8)
    }

    var gradientPlaceholder: some View {
        LinearGradient(
            colors: [Color.purple.opacity(0.7), Color.indigo.opacity(0.5)],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}

struct MediumSecondaryCard: View {
    let concert: WidgetConcert?
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                .padding(.top)

            if let concert {
                HStack(spacing: 8) {
                    // Mini Artist Bild
                    if let data = concert.artistImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .clipped()
                    } else {
                        Circle().fill(Color.purple.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(concert.artistName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .foregroundStyle(tint)

                        Text(concert.date.shortWidgetDate)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical)

                if let venue = concert.venueName {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(venue)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Rating Sterne falls vorhanden
                if let rating = concert.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < (rating / 2) ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.yellow)
                        }
                        Text("\(rating)/10")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Nichts\nvorhanden")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding(12)
    }
}

// MARK: - Large: Heute + Nächstes + Letztes

struct LargeWidgetView: View {
    let entry: ConcertEntry

    var body: some View {
        VStack(spacing: 0) {
            // Header - feste Höhe
            LargeHeaderCard(concert: entry.today ?? entry.next, isToday: entry.today != nil, tint: entry.appTint)
                .frame(maxHeight: 200)  // ← neu, ca. 60% des Large Widgets
                .clipped()

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)

            // Bottom Row
            HStack(spacing: 0) {
                LargeBottomCard(
                    concert: entry.today != nil ? entry.next : entry.last,
                    label: entry.today != nil ? "NÄCHSTES" : "LETZTES",
                    tint: entry.appTint
                )

                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                LargeBottomCard(concert: entry.last,
                                label: "LETZTES",
                                tint: entry.appTint)
            }
            .frame(maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct LargeHeaderCard: View {
    let concert: WidgetConcert?
    let isToday: Bool
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = concert?.artistImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .overlay(LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .bottom, endPoint: .center))
                    .frame(height: 200)
            } else {
                LinearGradient(colors: [.purple.opacity(0.7), .indigo.opacity(0.5)], startPoint: .bottomLeading, endPoint: .topTrailing)
                    .frame(height: 200)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isToday ? "HEUTE" : "NÄCHSTES KONZERT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isToday ? tint.opacity(0.8) : Color.white.opacity(0.2))
                    .clipShape(Capsule())

                if let concert {
                    Text(concert.title.isEmpty ? concert.artistName : concert.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(concert.artistName)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 12) {
                        if isToday, let openingTime = concert.openingTime {
                            Label(openingTime.widgetTimeString, systemImage: "calendar")
                        } else {
                            Label(concert.date.widgetDateString, systemImage: "calendar")
                        }
                        if let venue = concert.venueName {
                            Label(venue, systemImage: "mappin.circle.fill")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                } else {
                    Text("Kein Konzert geplant")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16)
        }
        .clipped()
    }
}

struct LargeBottomCard: View {
    let concert: WidgetConcert?
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())

            if let concert {
                HStack(spacing: 8) {
                    if let data = concert.artistImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle().fill(Color.purple.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }

                    Text(concert.artistName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(tint)
                }

                Text(concert.date.shortWidgetDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if let rating = concert.rating, rating > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < (rating / 2) ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.yellow)
                        }
                    }
                }
            } else {
                Text("–")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Date Helpers

private extension Date {
    var widgetDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd. MMM"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: self)
    }

    var widgetTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm 'Uhr'"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: self)
    }

    var shortWidgetDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd. MMM yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: self)
    }
}

// MARK: - Widget Configuration

@main
struct ConcertWidget: Widget {
    let kind: String = "ConcertWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConcertProvider()) { entry in
            ConcertWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Concert Journal")
        .description("Dein heutiges, nächstes und letztes Konzert.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
