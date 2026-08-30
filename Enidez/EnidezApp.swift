//
//  EnidezApp.swift
//  Enidez
//
//  Created by Enidez on 28/08/2026.
//

import SwiftUI

@main
struct EnidezApp: App {

    init() {
        Typeface.register()

        // Barre d'onglets : noir plein, filet discret, comme le reste de l'app.
        #if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.06)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
