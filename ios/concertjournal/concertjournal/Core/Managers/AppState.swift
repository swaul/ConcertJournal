//
//  AppState.swift
//  concertjournal
//
//  Created by Paul Arbetit on 19.02.26.
//

import Observation

@Observable
final class AppState {
    var pendingBuddyCode: String? = nil
    var showBuddyQuickAdd: Bool = false
}
