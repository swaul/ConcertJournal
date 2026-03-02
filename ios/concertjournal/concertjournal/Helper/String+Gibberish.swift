//
//  String+Gibberish.swift
//  concertjournal
//
//  Created by Paul Arbetit on 28.02.26.
//

extension String {
    static func randomGibberish(length: Int = 16) -> String {
        let specialChars = "!@#$%^&*()_+-=[]{}|;:',.<>?/~` "
        let numbers = "0123456789"
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let allChars = specialChars + numbers + letters
        
        return (0..<length)
            .map { _ in String(allChars.randomElement() ?? "?") }
            .joined()
    }
}
