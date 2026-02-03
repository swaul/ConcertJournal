//
//  MockUserSessionManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Supabase
import Foundation

class MockUserSessionManager: UserSessionManagerProtocol {

    var session: Session?
    var user: User?

    func start() async {
        self.session = nil
        self.user = .previewUser
    }
    
    func loadUser() async throws -> User {
        return .previewUser
    }

}

extension User {
    static var previewUser: User {
        User(id: UUID(), appMetadata: [:], userMetadata: [:], aud: "", createdAt: .now, updatedAt: .now)
    }
}
