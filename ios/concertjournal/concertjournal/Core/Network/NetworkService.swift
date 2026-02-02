//
//  NetworkService.swift
//  concertjournal
//
//  Generischer Network Service für API-Calls
//

import Foundation
import Supabase

enum NetworkError: Error, LocalizedError {
    case unauthorized
    case notFound
    case serverError(String)
    case decodingError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Nicht autorisiert"
        case .notFound:
            return "Ressource nicht gefunden"
        case .serverError(let message):
            return "Server Fehler: \(message)"
        case .decodingError:
            return "Daten konnten nicht verarbeitet werden"
        case .unknownError:
            return "Ein unbekannter Fehler ist aufgetreten"
        }
    }
}

protocol NetworkServiceProtocol {
    func fetch<T: Decodable>(
        from table: String,
        query: String,
        orderBy: String?,
        ascending: Bool
    ) async throws -> [T]

    func insert<T: Decodable>(
        into table: String,
        values: [String: AnyJSON]
    ) async throws -> T

    func update(
        table: String,
        id: String,
        values: [String: AnyJSON]
    ) async throws

    func delete(from table: String, id: String) async throws
}

/// Implementierung des Network Service mit Supabase
class NetworkService: NetworkServiceProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Fetch Data

    func fetch<T: Decodable>(
        from table: String,
        query: String = "*",
        orderBy: String? = nil,
        ascending: Bool = false
    ) async throws -> [T] {
        do {
            var queryBuilder = client.from(table).select(query)

            if let orderBy = orderBy {
                queryBuilder = queryBuilder.order(orderBy, ascending: ascending) as! PostgrestFilterBuilder
            }

            let response: [T] = try await queryBuilder.execute().value
            return response

        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch {
            throw NetworkError.unknownError
        }
    }

    // MARK: - Insert Data

    func insert<T: Decodable>(
        into table: String,
        values: [String: AnyJSON]
    ) async throws -> T {
        do {
            let result = try await client
                .from(table)
                .insert(values)
                .select()
                .single()
                .execute()
                .data

            return try JSONDecoder().decode(T.self, from: result)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch {
            throw NetworkError.unknownError
        }
    }

    // MARK: - Update Data

    func update(
        table: String,
        id: String,
        values: [String: AnyJSON]
    ) async throws {
        do {
            try await client
                .from(table)
                .update(values)
                .eq("id", value: id)
                .execute()

        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch {
            throw NetworkError.unknownError
        }
    }

    // MARK: - Delete Data

    func delete(from table: String, id: String) async throws {
        do {
            try await client
                .from(table)
                .delete()
                .eq("id", value: id)
                .execute()

        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch {
            throw NetworkError.unknownError
        }
    }

    // MARK: - Helper Methods

    private func mapPostgrestError(_ error: PostgrestError) -> NetworkError {
        // Map Supabase errors to our custom errors
        switch error.code {
        case "PGRST301":
            return .unauthorized
        case "PGRST116":
            return .notFound
        default:
            return .serverError(error.message)
        }
    }
}
