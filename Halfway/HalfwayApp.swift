import SwiftUI

@main
struct HalfwayApp: App {
    @StateObject private var locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(locationManager)
        }
    }
} 