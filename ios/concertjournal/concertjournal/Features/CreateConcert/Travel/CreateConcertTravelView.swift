//
//  CreateConcertTravelView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import SwiftUI

public struct CreateConcertTravelView: View {

    init(travel: TravelDTO?, onSave: @escaping (TravelDTO?) -> Void) {
        self.onSave = onSave

        if let selectedTravelType = travel?.travelType {
            self.selectedTravelType = selectedTravelType
        } else {
            self.selectedTravelType = nil
        }
        if let travelDuration = travel?.travelDuration {
            durationText = DurationParser.format(travelDuration)
        } else {
            durationText = ""
        }
        if let travelDistance = travel?.travelDistance {
            distanceText = DistanceParser.format(travelDistance)
        } else {
            distanceText = ""
        }
        if let arrivalTime = travel?.arrivedAt {
            arrivedAt = arrivalTime
        } else {
            arrivedAt = .now
        }
        if let travelExpenses = travel?.travelExpenses {
            expensesText = travelExpenses.formatted
        } else {
            expensesText = ""
        }
        if let hotelExpenses = travel?.hotelExpenses {
            hotelExpensesText = hotelExpenses.formatted
            spentTheNight = true
            animatedSpentTheNight = true
        } else {
            hotelExpensesText = ""
            spentTheNight = false
            animatedSpentTheNight = false
        }
    }

    var onSave: ((TravelDTO?) -> Void)?

    @State private var selectedTravelType: TravelType? = nil
    @State private var animatedSelectTravelType: TravelType? = nil

    @State var durationText: String
    @State var distanceText: String
    @State var expensesText: String
    @State var arrivedAt: Date
    @State var hotelExpensesText: String
    @State var spentTheNight: Bool
    @State var animatedSpentTheNight: Bool

    @State var arrivedAtSetByUser: Date? = nil

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Wie bist du zur location gekommen?")
                        .font(.cjBody)

                    HStack {
                        Menu {
                            ForEach(TravelType.allCases) { type in
                                Button {
                                    HapticManager.shared.buttonTap()
                                    selectedTravelType = type
                                } label: {
                                    Text(type.label)
                                        .font(.cjBody)
                                        .padding(4)
                                }
                            }
                        } label: {
                            Text("Hier auswählen")
                                .font(.cjBody)
                                .padding(4)
                        }
                        .buttonStyle(.glass)
                        .onChange(of: selectedTravelType) { _, newValue in
                            withAnimation(.bouncy) {
                                animatedSelectTravelType = newValue
                            }
                        }

                        Spacer()

                        if let selectedTravelType = animatedSelectTravelType {
                            Text(selectedTravelType.label)
                                .font(.cjBody)
                                .padding(12)
                                .glassEffect()
                                .transition(.move(edge: .trailing)
                                    .combined(with: .opacity))
                        }
                    }

                    Text("Wie lange hat die Reise gedauert?")
                        .font(.cjBody)
                        .padding(.top)

                    DurationValidatedTextField("z.B.: 3h 27m", text: $durationText)

                    Text("Wie groß war die Entfernung?")
                        .font(.cjBody)
                        .padding(.top)
                    DistanceValidatedTextField("z.B.: 346,5km", text: $distanceText)

                    Text("Wann bist du angekommen?")
                        .font(.cjBody)
                        .padding(.top)
                    DatePicker("", selection: $arrivedAt)
                        .onChange(of: arrivedAt) { oldValue, newValue in
                            arrivedAtSetByUser = newValue
                        }

                    Text("Wie teuer war die Reise?")
                        .font(.cjBody)
                        .padding(.top)
                    ExpensesValidatedTextField("z.B.: 38,99 €", text: $expensesText)

                    Toggle("Bist du über Nacht geblieben?", isOn: $spentTheNight)
                        .font(.cjBody)
                        .padding(.top)
                        .onChange(of: spentTheNight) { _, newValue in
                            withAnimation(.bouncy) {
                                animatedSpentTheNight = newValue
                            }
                        }
                    if animatedSpentTheNight {
                        Text("Wie teuer war die Übernachtung?")
                            .font(.cjBody)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        ExpensesValidatedTextField("z.B.: 149,89 €", text: $hotelExpensesText)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .font(.cjBody)
                .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Reise infos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.buttonTap()
                        saveValues()
                    } label: {
                        Text("Speichern")
                            .font(.cjBody)
                    }
                }
            }
        }
    }

    private func saveValues() {
        // Parse duration
        let travelDuration = DurationParser.parse(durationText)

        // Parse distance
        let travelDistance: Double? = DistanceParser.parse(distanceText)

        let arrivedAt: Date? = arrivedAtSetByUser

        // Parse travel expenses
        let travelExpenses = ExpensesParser.parse(expensesText)

        // Parse hotel expenses
        let hotelExpenses = spentTheNight ? ExpensesParser.parse(hotelExpensesText) : nil

        // Create Travel object
        let travel = TravelDTO(
            travelType: selectedTravelType,
            travelDuration: travelDuration,
            travelDistance: travelDistance,
            arrivedAt: arrivedAt,
            travelExpenses: travelExpenses,
            hotelExpenses: hotelExpenses
        )

        onSave?(travel)
    }
}

#Preview {
    CreateConcertTravelView(travel: nil, onSave: { _ in})
}

struct DistanceValidatedTextField: View {

    init(_ placeholder: String, text: Binding<String>) {
        self._text = text
        self.placeholder = placeholder
    }

    let placeholder: String

    @Binding var text: String

    @State private var isValid: Bool = true

    var previewLabel: String? {
        guard let parsedDistance = DistanceParser.parse(text) else { return nil }
        return DistanceParser.format(parsedDistance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            ValidatedTextField(placeholder: placeholder, text: $text)
                .onChange(of: text) { _, newValue in
                    withAnimation {
                        isValid = newValue.isEmpty || DistanceParser.parse(newValue) != nil
                    }
                }

            if !isValid {
                Text("Ungültiges Format")
                    .font(.cjCaption)
                    .foregroundStyle(.red)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let previewLabel {
                HStack {
                    Spacer()
                    Text("Preview:")
                        .font(.cjCaption)
                    Text(previewLabel)
                        .font(.cjCaption)
                }
            }
        }
    }
}

struct DurationValidatedTextField: View {

    init(_ placeholder: String, text: Binding<String>) {
        self._text = text
        self.placeholder = placeholder
    }

    let placeholder: String

    @Binding var text: String

    @State private var isValid: Bool = true

    var previewLabel: String? {
        guard let parsedDuration = DurationParser.parse(text) else { return nil }
        return DurationParser.format(parsedDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            ValidatedTextField(placeholder: placeholder, text: $text)
                .onChange(of: text) { _, newValue in
                    withAnimation {
                        isValid = newValue.isEmpty || DurationParser.parse(newValue) != nil
                    }
                }

            if !isValid {
                Text("Ungültiges Format")
                    .font(.cjCaption)
                    .foregroundStyle(.red)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let previewLabel {
                HStack {
                    Spacer()
                    Text("Preview:")
                        .font(.cjCaption)
                    Text(previewLabel)
                        .font(.cjCaption)
                }
            }
        }
    }
}

struct ExpensesValidatedTextField: View {

    init(_ placeholder: String, text: Binding<String>) {
        self._text = text
        self.placeholder = placeholder
    }

    let placeholder: String

    @Binding var text: String

    @State private var isValid: Bool = true

    var previewLabel: String? {
        guard let parsedPrice = ExpensesParser.parse(text) else { return nil }
        return parsedPrice.formatted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            ValidatedTextField(placeholder: placeholder, text: $text)
                .onChange(of: text) { _, newValue in
                    withAnimation {
                        isValid = newValue.isEmpty || ExpensesParser.parse(newValue) != nil
                    }
                }

            if !isValid {
                Text("Ungültiges Format")
                    .font(.cjCaption)
                    .foregroundStyle(.red)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let previewLabel {
                Text("Preview: \(previewLabel)")
                    .font(.cjFootnote)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("Preview:")
                    .font(.cjFootnote)
                    .foregroundStyle(.clear)
            }
        }
    }
}

struct EmailValidatedTextField: View {

    init(_ placeholder: String, text: Binding<String>) {
        self._text = text
        self.placeholder = placeholder
    }

    let placeholder: String

    @Binding var text: String

    @State private var isValid: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            ValidatedTextField(placeholder: placeholder, text: $text)
                .onChange(of: text) { _, newValue in
                    let valid = newValue.isEmpty || validateInput(input: newValue)
                    withAnimation {
                        isValid = valid
                    }
                }

            if !isValid {
                Text("Ungültiges Format")
                    .font(.cjCaption)
                    .foregroundStyle(.red)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    func validateInput(input: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"

        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: input)
    }
}


struct ValidatedTextField: View {

    let placeholder: String
    @Binding var text: String

    var body: some View {
            TextField(placeholder, text: $text)
                .font(.cjBody)
                .padding()
                .glassEffect()
    }
}
