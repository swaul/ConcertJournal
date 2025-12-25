//
//  FAQ.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.12.25.
//

struct FAQ: Identifiable, Decodable, Hashable {
    let id: String
    let question: String
    let answer: String
}
