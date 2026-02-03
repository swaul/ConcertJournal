//
//  MockLocalizationReposiotry.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

class MockLocalizationRepository: LocalizationRepositoryProtocol {

    var shouldFail = false
    var failureError: Error = NetworkError.unknownError
    var delay: TimeInterval = 0

    var texts: [String: String] = [:]

    func loadLocale(_ locale: String) async {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Mock implementation
    }

    func text(for key: String) -> String {
        return "Hey"
    }
}
