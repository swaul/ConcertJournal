//
//  TestView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.02.26.
//

#if DEBUG
import SwiftUI

struct TestSheet: View {

    @Binding var item: ShouldAddMoreInfoItem?

    var body: some View {
        VStack {
            Text("DAS HIER SOLL NUR EIN BISSCHEN AN TEXT SEIN DAMIT ICH DAS SHEET TESTEN KANN")
                .font(.cjTitle)

            Button("Schließen") {
                item = nil
            }
            .font(.cjLargeTitle)
            .buttonStyle(.glassProminent)
        }
    }
}

struct TestView: View {

    @State var isDynamicSheetPresenting: Bool = false
    @State var hasDynamicSheetItem: ShouldAddMoreInfoItem? = nil
    @State var combinationhasItemSheet: ShouldAddMoreInfoItem? = nil

    var body: some View {
        List {
            Section {
                Button("Dynamic sheet: isPresented:") {
                    isDynamicSheetPresenting = true
                }
                Button("Dynamic sheet: item:") {
                    hasDynamicSheetItem = ShouldAddMoreInfoItem(id: UUID(), count: 4, year: "2026")
                }
                Button("Dynamic sheet: combination") {
                    combinationhasItemSheet = ShouldAddMoreInfoItem(id: UUID(), count: 4, year: "2026")
                }
            } header: {
                Text("Sheets")
            }
        }
        .adaptiveSheet(isPresented: $isDynamicSheetPresenting) {
            ShouldAddMoreInfoView(item: ShouldAddMoreInfoItem(id: UUID(), count: 4, year: "2026"))
        }
        .adaptiveSheet(item: $hasDynamicSheetItem) { item in
            ShouldAddMoreInfoView(item: item)
        }
        .adaptiveSheet(item: $combinationhasItemSheet) { _ in
            TestSheet(item: $combinationhasItemSheet)
        }
    }
}

#Preview {
    TestView()
}
#endif
