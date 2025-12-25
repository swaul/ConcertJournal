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

class FAQViewModel: ObservableObject {
    
    @Published var faqLoadingState: FAQLoadingState = .loading
    
    func refresh() {
        Task {
            await loadData()
        }
    }
    
    func loadData() async {
        do {
            faqLoadingState = .loading
            let faq: [FAQ] = try await SupabaseManager.shared.client
                .from("faq_items")
                .select("id, question, answer")
                .eq("is_public", value: true)
                .order("order", ascending: true)
                .execute()
                .value
            
            faqLoadingState = .loaded(faq)
        } catch {
            print("COULD NOT LOAD FAQ")
            faqLoadingState = .error(error)
        }
    }
    
}

struct FAQView: View {
    
    @StateObject private var viewModel = FAQViewModel()
    
    var body: some View {
        Group {
            switch viewModel.faqLoadingState {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading")
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
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Retry") { viewModel.refresh() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("FAQ")
        .task { await viewModel.loadData() }
        .refreshable { viewModel.refresh() }
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
                        .font(.headline)
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
                    .font(.subheadline)
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

