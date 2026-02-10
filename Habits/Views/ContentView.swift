import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: HabitsViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch viewModel.permissionStatus {
            case .unknown:
                ProgressView("Requesting access...")
            case .authorized:
                MatrixView()
            case .denied:
                PermissionDeniedView()
            }
        }
        .task {
            await viewModel.checkAndRequestPermission()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshDayColumns()
                Task {
                    await viewModel.checkAndRequestPermission()
                }
            }
        }
    }
}
