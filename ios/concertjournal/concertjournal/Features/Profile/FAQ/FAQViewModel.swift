//
//  FAQViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Supabase
import Observation

@Observable
class FAQViewModel {
    
    var faqLoadingState: FAQLoadingState = .loading

    private let faqRepository: FAQRepositoryProtocol

    init(faqRepository: FAQRepositoryProtocol) {
        self.faqRepository = faqRepository
    }

    func refresh() {
        Task {
            await loadData()
        }
    }
    
    func loadData() async {
        do {
            faqLoadingState = .loading
            let faq: [FAQ] = try await faqRepository.getFAQ()
            faqLoadingState = .loaded(faq)
        } catch {
            print("COULD NOT LOAD FAQ")
            faqLoadingState = .error(error)
        }
    }
    
}
