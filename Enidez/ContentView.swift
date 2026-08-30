//
//  ContentView.swift
//  Enidez
//
//  Racine de l'app. Deux temps : le rituel du matin (plein écran), puis les
//  trois onglets. Le voile d'écoute du micro passe par-dessus tout.
//

import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Palette.screen.ignoresSafeArea()

            phase
                .environment(model)
                .transition(.opacity)

            if model.isListening {
                ListeningOverlay(name: model.name,
                                 transcript: model.speech.transcript,
                                 status: model.speech.status) {
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
            await model.loadHealthData()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { model.checkForEvening() }
        }
    }

    @ViewBuilder
    private var phase: some View {
        switch model.screen {
        case .welcome:     WelcomeView()
        case .onboarding:  OnboardingView()
        case .attune:      AttuneView()
        case .wakeUp:      WakeUpView()
        case .coffeeBreak: CoffeeBreakView()
        case .afterCoffee: AfterCoffeeView()
        case .triage:      TriageView()
        case .app:         AppTabs()
        case .evening:     EveningView()
        }
    }
}

/// Les trois onglets. Le minuteur de focus s'ouvre par-dessus, sans la barre.
struct AppTabs: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.tab) {
            TodayView()
                .tag(AppTab.today)
                .tabItem { Label("Aujourd'hui", systemImage: "sun.max") }

            UpcomingView()
                .tag(AppTab.upcoming)
                .tabItem { Label("À venir", systemImage: "calendar") }

            YouView()
                .tag(AppTab.you)
                .tabItem { Label("Toi", systemImage: "person") }
        }
        .tint(Palette.accent)
        .fullScreenCover(isPresented: $model.inFocus) {
            HyperfocusView()
                .environment(model)
        }
    }
}

#Preview {
    ContentView()
}
