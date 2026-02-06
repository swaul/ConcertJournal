//
//  CJLogger.swift
//  concertjournal
//
//  Created by Paul Kühnel on 06.02.26.
//

import Foundation
import OSLog

// MARK: - Log Level

enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case success = "✅ SUCCESS"
    case network = "🌐 NETWORK"
    case database = "💾 DATABASE"

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .success: return .info
        case .network: return .default
        case .database: return .default
        }
    }
}

// MARK: - Logger Category

enum LogCategory: String {
    case app = "App"
    case auth = "Auth"
    case concert = "Concert"
    case database = "Database"
    case setlist = "Setlist"
    case network = "Network"
    case repository = "Repository"
    case viewModel = "ViewModel"
    case ui = "UI"
    case supabase = "Supabase"
    case bff = "BFF"
}

// MARK: - App Logger

final class CJLogger {

    // MARK: - Singleton

    static let shared = CJLogger()

    // MARK: - Properties

    private let subsystem = Bundle.main.bundleIdentifier ?? "com.concertjournal"
    private var isDebugMode: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }

    // MARK: - Private Init

    private init() {}

    // MARK: - Main Logging Methods

    func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isDebugMode || level == .error else { return }

        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"

        // Log to OSLog
        logger.log(level: level.osLogType, "\(level.rawValue) \(formattedMessage)")

        // Also print for easier debugging in console
        print("[\(category.rawValue)] \(level.rawValue) \(formattedMessage)")
    }

    // MARK: - Convenience Methods

    func debug(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, error: Error? = nil, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        let fullMessage = error != nil ? "\(message) - Error: \(error!.localizedDescription)" : message
        log(fullMessage, level: .error, category: category, file: file, function: function, line: line)
    }

    func success(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, category: category, file: file, function: function, line: line)
    }

    // MARK: - Network Logging

    func networkRequest(
        method: String,
        url: String,
        headers: [String: String]? = nil,
        body: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = "→ \(method) \(url)"
        if let headers = headers, !headers.isEmpty {
            message += "\nHeaders: \(headers)"
        }
        if let body = body {
            message += "\nBody: \(body)"
        }
        log(message, level: .network, category: .network, file: file, function: function, line: line)
    }

    func networkResponse(
        url: String,
        statusCode: Int,
        responseTime: TimeInterval? = nil,
        body: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = "← [\(statusCode)] \(url)"
        if let time = responseTime {
            message += " (\(String(format: "%.2f", time))s)"
        }
        if let body = body {
            message += "\nResponse: \(body)"
        }
        let level: LogLevel = (200...299).contains(statusCode) ? .success : .error
        log(message, level: level, category: .network, file: file, function: function, line: line)
    }

    func networkError(
        url: String,
        error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("Network error for \(url): \(error.localizedDescription)", level: .error, category: .network, file: file, function: function, line: line)
    }

    // MARK: - Database Logging

    func databaseQuery(
        _ query: String,
        parameters: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var message = "Query: \(query)"
        if let params = parameters, !params.isEmpty {
            message += "\nParameters: \(params)"
        }
        log(message, level: .database, category: .database, file: file, function: function, line: line)
    }

    func databaseResult(
        count: Int,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("Query returned \(count) result(s)", level: .success, category: .database, file: file, function: function, line: line)
    }

    // MARK: - Performance Tracking

    func measureTime<T>(
        _ description: String,
        category: LogCategory = .app,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(start)
        success("\(description) completed in \(String(format: "%.2f", duration))s", category: category)
        return result
    }
}

// MARK: - Global Convenience Functions

func logDebug(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    CJLogger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    CJLogger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    CJLogger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, error: Error? = nil, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    CJLogger.shared.error(message, error: error, category: category, file: file, function: function, line: line)
}

func logSuccess(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    CJLogger.shared.success(message, category: category, file: file, function: function, line: line)
}
