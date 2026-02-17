//
//  SyncStatus.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

enum SyncStatus: String {
    case synced         // In sync with server
    case pending        // Local changes not yet synced
    case syncing        // Currently syncing
    case conflict       // Server has newer version
    case error          // Sync failed
    case deleted        // Marked for deletion
}
