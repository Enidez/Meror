//
//  ContentView.swift
//  Enidez
//
//  Hôte du parcours « Un jour ». Affiche une seule chose à la fois,
//  avec le voile d'écoute du micro par-dessus quand l'assistant écoute.
//

import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        ZStack {
            Palette.screen.ignoresSafeArea()

            currentScreen
                .environment(model)
                .transition(.opacity)
                .id(screenID)

            if model.isListening {
                ListeningOverlay(name: model.name) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        model.isListening = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        #endif
        .task {
            // Charge le sommeil et l'activité depuis Apple Santé au lancement.
            await model.loadHealthData()
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch model.screen {
        case .welcome:     WelcomeView()
        case .wakeUp:      WakeUpView()
        case .coffeeBreak: CoffeeBreakView()
        case .afterCoffee: AfterCoffeeView()
        case .twoThings:   TwoThingsView()
        case .today:       TodayView()
        case .hyperfocus:  HyperfocusView()
        case .upcoming:    UpcomingView()
        case .evolution:   EvolutionView()
        case .profile:     ProfileView()
        }
    }

    /// Force un fondu propre entre écrans.
    private var screenID: Int {
        switch model.screen {
        case .welcome: 0
        case .wakeUp: 1
        case .coffeeBreak: 2
        case .afterCoffee: 3
        case .twoThings: 4
        case .today: 5
        case .hyperfocus: 6
        case .upcoming: 7
        case .evolution: 8
        case .profile: 9
        }
    }
}

#Preview {
    ContentView()
}
