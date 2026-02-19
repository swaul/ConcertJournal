//
//  BuddiesViewModel.swift
//  concertjournal
//

import CoreImage.CIFilterBuiltins
import Observation
import Supabase
import SwiftUI

enum BuddiesLoadingState {
    case loading
    case loaded
    case error
}

@Observable
final class BuddiesViewModel {
    
    // MARK: - State
    
    var loadingState: BuddiesLoadingState = .loading
    var buddies: [Buddy] = []
    var incomingRequests: [BuddyRequest] = []
    var outgoingRequests: [BuddyRequest] = []
    
    // Eigener Code
    var myBuddyCode: String? = nil
    var qrImage: UIImage? = nil
    var isRegeneratingCode = false
    
    // Suche
    var searchQuery: String = ""
    var searchResults: [UserSearchResult] = []
    var searchState: SearchState = .idle
    
    // Fehler
    var errorMessage: String? = nil
    
    private var currentUserId: String {
        userProvider.user?.id.uuidString.lowercased() ?? ""
    }
    
    enum SearchState {
        case idle, searching, results, empty, error
    }
        
    // MARK: - Dependencies
    
    private let supabaseClient: SupabaseClientManagerProtocol
    private let userProvider: UserSessionManagerProtocol
    
    init(supabaseClient: SupabaseClientManagerProtocol, userProvider: UserSessionManagerProtocol) {
        self.supabaseClient = supabaseClient
        self.userProvider = userProvider
    }
    
    // MARK: - Load
    
    @MainActor
    func load() async {
        loadingState = .loading
        logInfo("Loading buddies, requests, and buddy code")
        async let buddiesTask: () = fetchBuddies()
        async let requestsTask: () = fetchRequests()
        async let codeTask: () = fetchOrCreateBuddyCode()
        _ = await (buddiesTask, requestsTask, codeTask)
        logInfo("Finished loading BuddiesViewModel state")
        loadingState = .loaded
    }
    
    @MainActor
    private func fetchBuddies() async {
        do {
            logInfo("Fetching buddies for user: \(currentUserId)")
            let rows: [BuddyRow] = try await supabaseClient.client
                .from("friendships")
                .select("""
                    id,
                    requester_id,
                    addressee_id,
                    status,
                    created_at,
                    requester:profiles!requester_id(id, display_name, avatar_url),
                    addressee:profiles!addressee_id(id, display_name, avatar_url),
                    shared_concerts
                """)
                .eq("status", value: "accepted")
                .or("requester_id.eq.\(currentUserId),addressee_id.eq.\(currentUserId)")
                .execute()
                .value
            
            buddies = rows.compactMap { row in
                let isRequester = row.requesterId == currentUserId
                let profile = isRequester ? row.addressee : row.requester
                guard let profile else { return nil }
                return Buddy(
                    id: row.id,
                    userId: profile.id,
                    displayName: profile.displayName,
                    avatarURL: profile.avatarUrl.flatMap { URL(string: $0) },
                    sharedConcerts: row.sharedConcerts ?? 0,
                    lastActivity: row.createdAt
                )
            }
            logSuccess("Fetched \(buddies.count) buddies")
        } catch {
            logError("Error fetching buddies: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func fetchRequests() async {
        do {
            logInfo("Fetching requests for user: \(currentUserId)")
            let rows: [BuddyRequestRow] = try await supabaseClient.client
                .from("friendships")
                .select("""
                    id,
                    requester_id,
                    addressee_id,
                    status,
                    created_at,
                    requester:profiles!requester_id(id, display_name, avatar_url),
                    addressee:profiles!addressee_id(id, display_name, avatar_url)
                """)
                .eq("status", value: "pending")
                .or("requester_id.eq.\(currentUserId),addressee_id.eq.\(currentUserId)")
                .execute()
                .value
            
            incomingRequests = rows
                .filter { $0.addresseeId.lowercased() == currentUserId.lowercased() }
                .compactMap { row in
                    guard let profile = row.requester else { return nil }
                    return BuddyRequest(id: row.id, userId: profile.id, displayName: profile.displayName,
                                        avatarURL: profile.avatarUrl.flatMap { URL(string: $0) },
                                        createdAt: row.createdAt, direction: .incoming)
                }
            
            outgoingRequests = rows
                .filter { $0.requesterId.lowercased() == currentUserId.lowercased() }
                .compactMap { row in
                    guard let profile = row.addressee else { return nil }
                    return BuddyRequest(id: row.id, userId: profile.id, displayName: profile.displayName,
                                        avatarURL: profile.avatarUrl.flatMap { URL(string: $0) },
                                        createdAt: row.createdAt, direction: .outgoing)
                }
            logSuccess("Fetched incoming: \(incomingRequests.count), outgoing: \(outgoingRequests.count) requests")
        } catch {
            logError("Error fetching requests: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Buddy Code
    
    @MainActor
    func fetchOrCreateBuddyCode() async {
        guard let userId = userProvider.user?.id.uuidString else { return }
        logInfo("Fetching buddy code for current user")
        do {
            let rows: [BuddyCodeRow] = try await supabaseClient.client
                .from("profiles")
                .select("buddy_code")
                .eq("id", value: userId)
                .execute()
                .value
            
            if let code = rows.first?.buddyCode {
                myBuddyCode = code
                qrImage = generateQRCode(from: code)
                logSuccess("Loaded buddy code for current user")
            }
        } catch {
            logError("Error fetching buddy code: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func regenerateBuddyCode() async {
        guard let userId = userProvider.user?.id.uuidString else { return }
        isRegeneratingCode = true
        logInfo("Regenerating buddy code requested")
        defer { isRegeneratingCode = false }
        
        do {
            let newCode: String = try await supabaseClient.client
                .rpc("regenerate_buddy_code", params: ["user_id": userId])
                .execute()
                .value
            
            myBuddyCode = newCode
            qrImage = generateQRCode(from: newCode)
            logSuccess("Successfully regenerated buddy code")
            HapticManager.shared.buttonTap()
        } catch {
            logError("Failed to regenerate buddy code: \(error.localizedDescription)")
            errorMessage = "Code konnte nicht erneuert werden."
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        logInfo("Generating QR code for string length: \(string.count)")
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        // Deep-Link damit die App ihn direkt verarbeiten kann
        filter.message = Data("concertjournal://buddy/\(string)".utf8)
        filter.correctionLevel = "M"
        
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        logSuccess("QR code image generated successfully")
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - QR Scan Result verarbeiten
    
    @MainActor
    func handleScannedCode(_ raw: String) async {
        logInfo("Handling scanned code: \(raw)")
        let code: String
        if let url = URL(string: raw),
           url.scheme == "concertjournal",
           url.host == "buddy",
           let extracted = url.pathComponents.last, extracted != "/" {
            code = extracted
        } else if raw.count == 6 {
            code = raw
        } else {
            logError("Invalid QR code scanned")
            errorMessage = "Ungültiger QR-Code."
            return
        }
        searchQuery = code
        logSuccess("Searching by scanned code: \(code)")
        await searchByCode(code)
    }
    
    // MARK: - Suche
    
    @MainActor
    func searchByCode(_ code: String) async {
        logInfo("Searching user by code: \(code)")
        searchState = .searching
        do {
            let rows: [ProfileRow] = try await supabaseClient.client
                .from("profiles")
                .select("id, display_name, avatar_url, buddy_code")
                .eq("buddy_code", value: code.uppercased())
                .neq("id", value: currentUserId)
                .limit(1)
                .execute()
                .value
            
            let buddyIds = Set(buddies.map(\.userId))
            let pendingIds = Set((incomingRequests + outgoingRequests).map(\.userId))
            
            searchResults = rows.map { row in
                UserSearchResult(
                    id: row.id,
                    displayName: row.displayName,
                    avatarURL: row.avatarUrl.flatMap { URL(string: $0) },
                    buddyCode: row.buddyCode,
                    relationStatus: buddyIds.contains(row.id) ? .alreadyFriends
                    : pendingIds.contains(row.id) ? .pending
                    : .none
                )
            }
            logSuccess("Search by code returned \(searchResults.count) result(s)")
            searchState = searchResults.isEmpty ? .empty : .results
        } catch {
            logError("Search by code failed", error: error)
            searchState = .error
        }
    }
    
    @MainActor
    func searchUsers() async {
        logInfo("searchUsers called with query: \(searchQuery)")
        let query = searchQuery.trimmingCharacters(in: .whitespaces).uppercased()
        guard query.count >= 2 else {
            logInfo("Query too short, resetting search state")
            searchState = .idle
            searchResults = []
            return
        }
        if query.count == 6, query.allSatisfy({ $0.isLetter || $0.isNumber }) {
            logInfo("Query looks like buddy code, performing code search")
            await searchByCode(query)
        } else {
            // Weniger als 6 Zeichen: noch kein API-Call, warte auf vollständigen Code
            logSuccess("Partial query, awaiting full code before searching")
            searchState = .idle
            searchResults = []
        }
    }
    
    func clearSearch() {
        logInfo("Clearing search state and query")
        searchQuery = ""
        searchResults = []
        searchState = .idle
    }
    
    // MARK: - Anfragen
    
    @MainActor
    func sendRequest(to userId: String) async {
        logInfo("Sending buddy request to user: \(userId)")
        guard !currentUserId.isEmpty else { return }
        do {
            try await supabaseClient.client
                .from("friendships")
                .insert(["requester_id": currentUserId, "addressee_id": userId, "status": "pending"])
                .execute()
            if let idx = searchResults.firstIndex(where: { $0.id == userId }) {
                searchResults[idx].relationStatus = .pending
            }
            logSuccess("Buddy request sent to user: \(userId)")
            HapticManager.shared.buttonTap()
        } catch {
            logError("Failed to send buddy request", error: error)
            errorMessage = "Anfrage konnte nicht gesendet werden."
        }
    }
    
    @MainActor
    func acceptRequest(_ request: BuddyRequest) async {
        logInfo("Accepting request id: \(request.id) from user: \(request.userId)")
        do {
            try await supabaseClient.client
                .from("friendships").update(["status": "accepted"]).eq("id", value: request.id).execute()
            incomingRequests.removeAll { $0.id == request.id }
            buddies.append(Buddy(id: request.id, userId: request.userId, displayName: request.displayName,
                                 avatarURL: request.avatarURL, sharedConcerts: 0, lastActivity: request.createdAt))
            logSuccess("Accepted request id: \(request.id)")
            HapticManager.shared.buttonTap()
        } catch {
            logError("Failed to accept request id: \(request.id)", error: error)
            errorMessage = "Anfrage konnte nicht akzeptiert werden."
        }
    }
    
    @MainActor
    func declineRequest(_ request: BuddyRequest) async {
        logInfo("Declining request id: \(request.id)")
        do {
            try await supabaseClient.client.from("friendships").delete().eq("id", value: request.id).execute()
            incomingRequests.removeAll { $0.id == request.id }
            logSuccess("Declined request id: \(request.id)")
            HapticManager.shared.buttonTap()
        } catch {
            logError("Failed to decline request id: \(request.id)", error: error)
            errorMessage = "Anfrage konnte nicht abgelehnt werden."
        }
    }
    
    @MainActor
    func cancelRequest(_ request: BuddyRequest) async {
        do {
            try await supabaseClient.client
                .from("friendships")
                .delete()
                .eq("id", value: request.id)
                .execute()
            outgoingRequests.removeAll { $0.id == request.id }
            HapticManager.shared.buttonTap()
        } catch {
            errorMessage = "Anfrage konnte nicht zurückgezogen werden."
        }
    }
    
    @MainActor
    func removeBuddy(_ buddy: Buddy) async {
        logInfo("Removing buddy id: \(buddy.id) userId: \(buddy.userId)")
        do {
            try await supabaseClient.client.from("friendships").delete().eq("id", value: buddy.id).execute()
            buddies.removeAll { $0.id == buddy.id }
            logSuccess("Removed buddy id: \(buddy.id)")
            HapticManager.shared.buttonTap()
        } catch {
            logError("Failed to remove buddy id: \(buddy.id): \(error.localizedDescription)")
            errorMessage = "Freund konnte nicht entfernt werden."
        }
    }
}

// MARK: - Models

struct Buddy: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let avatarURL: URL?
    let sharedConcerts: Int
    let lastActivity: Date
}

struct BuddyRequest: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let avatarURL: URL?
    let createdAt: Date
    let direction: Direction
    enum Direction { case incoming, outgoing }
}

struct UserSearchResult: Identifiable {
    let id: String
    let displayName: String
    let avatarURL: URL?
    let buddyCode: String?
    var relationStatus: RelationStatus
    enum RelationStatus { case none, pending, alreadyFriends }
}

// MARK: - Supabase Row Models

private struct BuddyRow: Decodable {
    let id: String
    let requesterId: String
    let addresseeId: String
    let status: String
    let createdAt: Date
    let requester: ProfileRow?
    let addressee: ProfileRow?
    let sharedConcerts: Int?
    enum CodingKeys: String, CodingKey {
        case id, status, requester, addressee
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case createdAt = "created_at"
        case sharedConcerts = "shared_concerts"
    }
}

private struct BuddyRequestRow: Decodable {
    let id: String
    let requesterId: String
    let addresseeId: String
    let status: String
    let createdAt: Date
    let requester: ProfileRow?
    let addressee: ProfileRow?
    enum CodingKeys: String, CodingKey {
        case id, status, requester, addressee
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case createdAt = "created_at"
    }
}

private struct ProfileRow: Decodable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let buddyCode: String?
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case buddyCode = "buddy_code"
    }
}

private struct BuddyCodeRow: Decodable {
    let buddyCode: String?
    enum CodingKeys: String, CodingKey {
        case buddyCode = "buddy_code"
    }
}
