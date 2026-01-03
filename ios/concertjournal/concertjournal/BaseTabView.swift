//
//  BaseTabView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.01.26.
//

import SwiftUI

struct BaseTabView: View {
    
    @ObservedObject var userManager: UserSessionManager

    var body: some View {
        TabView {
            Tab {
                ConcertsView(userManager: userManager)
            }
            Tab {
                
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
