import SwiftUI

@main
struct HabitsApp: App {
    @StateObject private var viewModel = HabitsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
