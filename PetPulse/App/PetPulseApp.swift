import SwiftData
import SwiftUI

@main
struct PetPulseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .tint(PP.teal)
        }
        .modelContainer(for: [Pet.self, DailyCheckIn.self, TimelineEvent.self])
    }
}

enum Route: Hashable {
    case checkIn, baseline, changes, timeline, vetSummary, more, profile
}

@Observable
final class Router {
    var path: [Route] = []
}

/// Onboarding until a pet exists, then the main app.
struct RootView: View {
    @Query private var pets: [Pet]

    var body: some View {
        if let pet = pets.first {
            MainView(pet: pet)
        } else {
            NavigationStack { SplashView() }
        }
    }
}

struct MainView: View {
    var pet: Pet
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(pet: pet)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .checkIn: CheckInView(pet: pet)
                    case .baseline: BaselineView(pet: pet)
                    case .changes: ChangesView(pet: pet)
                    case .timeline: HealthTimelineView(pet: pet)
                    case .vetSummary: VetSummaryView(pet: pet)
                    case .more: MoreView(pet: pet)
                    case .profile: ProfileView(pet: pet)
                    }
                }
        }
        .environment(router)
    }
}
