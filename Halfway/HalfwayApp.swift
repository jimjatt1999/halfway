import SwiftUI
import MapKit

@main
struct HalfwayApp: App {
    @StateObject private var locationManager = LocationManager()
    @State private var showLaunchScreen = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainView()
                    .environmentObject(locationManager)
                
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Dismiss the launch screen after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}

struct LaunchScreenView: View {
    @State private var isTitleAnimating = false
    @State private var halfOffset: CGFloat = 0
    @State private var wayOffset: CGFloat = 0
    @State private var titleScale: CGFloat = 1.0
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    
    // Random tagline selection
    private let taglines = [
        "Let's meet halfway",
        "Find the perfect middle ground",
        "The smart way to meet up",
        "Halfway there, everywhere",
        "Bringing people together",
        "Meeting made simple"
    ]
    
    private var randomTagline: String {
        taglines.randomElement() ?? "Let's meet halfway"
    }
    
    var body: some View {
        ZStack {
            // Blur background
            BlurView(style: .systemMaterialDark)
                .ignoresSafeArea()
            
            // Dark overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            // Title animation and tagline
            VStack(spacing: 20) {
                HStack(spacing: 0) {
                    Text("Half")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: halfOffset)
                        .scaleEffect(titleScale)
                        .opacity(titleOpacity)
                        
                    Text("way")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: wayOffset)
                        .scaleEffect(titleScale)
                        .opacity(titleOpacity)
                }
                
                // Tagline with fade-in animation after title animation
                Text(randomTagline)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(taglineOpacity)
                    .padding(.top, 4)
            }
            .padding()
        }
        .onAppear {
            animateTitle()
        }
    }
    
    private func animateTitle() {
        // Fade in first
        withAnimation(.easeIn(duration: 0.3)) {
            titleOpacity = 1.0
        }
        
        // Wait a moment before starting movement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // First animation - separate the words
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)) {
                halfOffset = -40
                wayOffset = 40
                titleScale = 1.3
            }
            
            // Second animation - bounce back with slight overshoot
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.2)) {
                    halfOffset = -8
                    wayOffset = 8
                }
                
                // Third animation - return to original state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)) {
                        halfOffset = 0
                        wayOffset = 0
                        titleScale = 1.0
                    }
                    
                    // Fade in tagline after title animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeIn(duration: 0.5)) {
                            taglineOpacity = 1.0
                        }
                    }
                }
            }
        }
    }
} 