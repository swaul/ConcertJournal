//
//  DynamicBottomSheet.swift
//  concertjournal
//
//  Created by Paul Kühnel on 13.02.26.
//

import SwiftUI

extension View {
    func adaptiveSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder sheetContent: () -> Content) -> some View {
        modifier(AdaptiveSheetModifier(isPresented: isPresented, sheetContent))
    }

    func adaptiveSheet<Content: View, Item: Identifiable>(item: Binding<Item?>, @ViewBuilder sheetContent: @escaping (Item) -> Content) -> some View {
        modifier(AdaptiveItemSheetModifier(item: item, content: sheetContent))
    }
}

struct AdaptiveSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @State private var subHeight: CGFloat = 0
    var sheetContent: SheetContent

    init(isPresented: Binding<Bool>, @ViewBuilder _ content: () -> SheetContent) {
        _isPresented = isPresented
        sheetContent = content()
    }

    func body(content: Content) -> some View {
        content
            .background(
                sheetContent
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .task(id: proxy.size.height) {
                                    subHeight = proxy.size.height
                                }
                        }
                    )
                    .hidden()
            )
            .sheet(isPresented: $isPresented) {
                sheetContent
                    .presentationDetents([.height(subHeight)])
            }
            .id(subHeight)
    }
}

struct AdaptiveItemSheetModifier<SheetContent: View, Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    @State private var subHeight: CGFloat = 0
    let content: (Item) -> SheetContent

    init(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> SheetContent) {
        _item = item
        self.content = content
    }

    func body(content base: Content) -> some View {
        base
            .background(
                Group {
                    if let item = item {
                        self.content(item)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .task(id: proxy.size.height) {
                                            subHeight = proxy.size.height
                                        }
                                }
                            )
                            .hidden()
                    }
                }
            )
            .sheet(item: $item) { item in
                self.content(item)
                    .presentationDetents([.height(subHeight == 0  ? 200 : subHeight)])
            }
    }
}
