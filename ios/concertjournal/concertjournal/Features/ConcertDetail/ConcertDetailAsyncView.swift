//
//  ConcertDetailAsyncView.swift
//  concertjournal
//
//  Created by Paul Arbetit on 27.02.26.
//

import SwiftUI

struct ConcertDetailAsyncView: View {
    
    let id: String
    
    @State var concert: ServerConcert? = nil
    
    var body: some View {
        Text("Sorry ich konnte das Konzert mit der id \(id) leider nicht finden")
            .font(.cjHeadline)
            .padding()
    }
}
