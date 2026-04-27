import SwiftUI

@main
struct UrDigiDietApp: App {
    // App 層級就初始化，比 ContentView 更早，加速第一幀渲染
    @StateObject private var store = DataStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
