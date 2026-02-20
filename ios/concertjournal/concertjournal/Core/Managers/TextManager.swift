//
//  TextManager.swift
//  concertjournal
//
//  Created by Paul Arbetit on 20.02.26.
//

import Foundation

// MARK: - TextManager

final class TextManager {
    static let shared = TextManager()
    
    private var localizationManager: LocalizationManager?
    
    private init() {}
    
    func configure(with localizationManager: LocalizationManager) {
        self.localizationManager = localizationManager
    }
    
    // MARK: - String Access
    
    func string(for key: TextKey) -> String {
        localizationManager?.string(for: key.rawValue) ?? key.rawValue
    }
    
    func string(for key: TextKey, with arguments: CVarArg...) -> String {
        guard let manager = localizationManager else { return key.rawValue }
        let template = manager.strings[key.rawValue] ?? key.rawValue
        return String(format: template, arguments: arguments)
    }
}
