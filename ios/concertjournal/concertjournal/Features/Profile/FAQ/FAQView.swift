//
//  FAQView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.12.25.
//

import Combine
import SwiftUI
import Supabase

enum FAQLoadingState {
    case loading
    case loaded([FAQ])
    case error(Error)
}



struct FAQView: View {

    @Environment(\.dependencies) var dependencies

    @State private var viewModel: FAQViewModel?

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.faqLoadingState {
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(TextKey.stateLoading.localized)
                            .font(.cjBody)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let array):
                    List {
                        ForEach(array) { item in
                            FAQRow(item: item)
                                .listRowSeparator(.visible)
                        }
                    }
                    .listStyle(.insetGrouped)
                case .error(let error):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.cjTitle2)
                            .foregroundStyle(.orange)
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                            .font(.cjBody)
                            .foregroundStyle(.secondary)
                        Button {
                            HapticManager.shared.buttonTap()
                            viewModel.refresh()
                        } label: {
                            Text(TextKey.reload.localized)
                                .font(.cjBody)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                LoadingView()
            }
        }
        .navigationTitle("FAQ")
        .task {
            guard viewModel == nil else { return }
            viewModel = FAQViewModel(faqRepository: dependencies.faqRepository)
            await viewModel?.loadData()
        }
        .refreshable { viewModel?.refresh() }
    }
}

private struct FAQRow: View {
    let item: FAQ
    @State var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.question)
                        .font(.cjHeadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.cjBody)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(item.question))
        .accessibilityHint(Text("Tap to " + (isExpanded ? "collapse" : "expand")))
    }
}

