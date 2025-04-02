import SwiftUI
import MapKit

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.accentColor.opacity(0.2), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(currentPage == index ? 1.1 : 1.0)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.top, 20)
                
                // Page content
                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    VStack(spacing: 30) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                            .padding(.bottom, 20)
                        
                        Text("Welcome to Halfway")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("The best way to find the perfect meeting point between locations")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .foregroundColor(.secondary)
                        
                        Text("Discover restaurants, cafes, parks and more at your ideal midpoint")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .tag(0)
                    .padding(.top, 40)
                    
                    // Page 2: How it works
                    VStack(spacing: 25) {
                        Text("How It Works")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        MapDemonstrationView()
                            .frame(height: 300)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            FeatureRow(icon: "mappin.and.ellipse", text: "Enter up to five locations")
                            FeatureRow(icon: "point.topleft.down.to.point.bottomright.up", text: "Find the perfect midpoint")
                            FeatureRow(icon: "magnifyingglass", text: "Discover places to meet")
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                    .tag(1)
                    
                    // Page 3: Add Locations
                    VStack(spacing: 25) {
                        Text("Ways to Add Locations")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: "1.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enter in search field")
                                        .font(.headline)
                                    Text("Add up to 5 locations and tap \"Find Meeting Places\"")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: "2.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Long-press on map")
                                        .font(.headline)
                                    Text("Quickly add up to 5 locations directly on the map")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: "3.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use current location")
                                        .font(.headline)
                                    Text("Add your present position with one tap")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        Image(systemName: "location.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                            .padding()
                            .background(Circle().fill(Color.accentColor.opacity(0.2)))
                        
                        Spacer()
                    }
                    .tag(2)
                    
                    // Page 4: Tips and Tricks
                    VStack(spacing: 25) {
                        Text("Power Tips")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            TipRow(number: "01", title: "Search & Filter", description: "Search for places by name or category like 'food' or 'coffee'")
                            
                            TipRow(number: "02", title: "Adjust Search Radius", description: "Use the slider to expand or narrow your search area")
                            
                            TipRow(number: "03", title: "Return to Midpoint", description: "Press the location button to navigate back to the midpoint")
                            
                            TipRow(number: "04", title: "Start Over", description: "Drag results panel down to return to location entry")
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .padding()
                            .foregroundColor(.gray)
                        }
                    } else {
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            if currentPage < 3 {
                                currentPage += 1
                            } else {
                                // Finish onboarding
                                isOnboardingCompleted = true
                                // Save that we've completed onboarding
                                UserDefaults.standard.set(true, forKey: "isOnboardingCompleted")
                            }
                        }
                    }) {
                        HStack {
                            Text(currentPage < 3 ? "Next" : "Get Started")
                            Image(systemName: currentPage < 3 ? "chevron.right" : "checkmark")
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .padding(.vertical)
        }
    }
}

// Helper Views
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .foregroundColor(.white)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.headline)
            
            Spacer()
        }
    }
}

struct TipRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Text(number)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingCompleted: .constant(false))
    }
} 