//
//  AppView.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/29/26.
//

import SwiftUI

struct AppView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.2, blue: 0.4),
                Color(red: 0.2, green: 0.1, blue: 0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    AppView()
}
