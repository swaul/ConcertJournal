//
//  PlaylistImport.swift
//  concertjournal
//
//  Created by Paul Kühnel on 06.02.26.
//

import SwiftUI

public struct PlaylistImport: View {
    public var body: some View {
        Text("PlaylistImport")
            .task {
                
            }
    }
    
    func getplaylists() {
        "https://api.spotify.com/v1/me/playlists"
    }
    
    func getToken() {
        
    }
}
