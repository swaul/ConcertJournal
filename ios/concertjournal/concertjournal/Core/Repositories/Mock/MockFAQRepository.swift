//
//  MockFAQRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

class MockFAQRepository: FAQRepositoryProtocol {

    var shouldFail = false
    var failureError: Error = NetworkError.unknownError
    var delay: TimeInterval = 0

    var mockFAQs: [FAQ] = []

    func getFAQ() async throws -> [FAQ] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockFAQs
    }
}
