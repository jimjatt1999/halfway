import SwiftUI
import MapKit

struct MapDemonstrationView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),  // San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    @State private var isAnimating = false
    @State private var showTooltip = false
    @State private var locations = [
        DemoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), name: "You", color: .blue),
        DemoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2711), name: "Friend 1", color: .green),
        DemoLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7330, longitude: -122.3255), name: "Friend 2", color: .purple)
    ]
    
    @State private var midpoint = CLLocationCoordinate2D(latitude: 37.7708, longitude: -122.3387)
    @State private var showMidpoint = false
    @State private var showAnimation = false
    @State private var showFingerTap = false
    @State private var showPlaces = false
    
    // Helper properties to break down complex expressions
    private func screenPositionX(for coordinate: CLLocationCoordinate2D) -> CGFloat {
        let longitudeDelta = region.span.longitudeDelta
        let centerLongitude = region.center.longitude
        let screenWidth = UIScreen.main.bounds.width
        
        let factor = (coordinate.longitude - centerLongitude) / longitudeDelta
        return CGFloat(factor * Double(screenWidth) + Double(screenWidth) / 2)
    }
    
    private func screenPositionY(for coordinate: CLLocationCoordinate2D) -> CGFloat {
        let latitudeDelta = region.span.latitudeDelta
        let centerLatitude = region.center.latitude
        let screenHeight = UIScreen.main.bounds.height
        
        let factor = (centerLatitude - coordinate.latitude) / latitudeDelta
        return CGFloat(factor * Double(screenHeight) + Double(screenHeight) / 2)
    }
    
    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $region, annotationItems: locations) { location in
                MapAnnotation(coordinate: location.coordinate) {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 36, height: 36)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(location.color)
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: location.name == "You" ? "person.fill" : "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        
                        Text(location.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
            }
            .overlay(
                Group {
                    if showMidpoint {
                        // Add midpoint marker
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 46, height: 46)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "mappin")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            
                            // Pulsating ring animation
                            Circle()
                                .stroke(Color.red.opacity(0.5), lineWidth: 3)
                                .frame(width: 60, height: 60)
                                .scaleEffect(isAnimating ? 1.5 : 1.0)
                                .opacity(isAnimating ? 0.0 : 1.0)
                        }
                        .position(
                            x: screenPositionX(for: midpoint),
                            y: screenPositionY(for: midpoint)
                        )
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                        .onAppear {
                            isAnimating = true
                        }
                        
                        // Midpoint label
                        Text("Midpoint")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .position(
                                x: screenPositionX(for: midpoint),
                                y: screenPositionY(for: midpoint) - 40
                            )
                    }
                    
                    if showPlaces {
                        // Show a couple example places
                        ForEach(demoPlaces, id: \.id) { place in
                            PlacePin(place: place, coordToScreenX: screenPositionX, coordToScreenY: screenPositionY)
                        }
                    }
                }
            )
            
            // Finger tap animation
            if showFingerTap {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "hand.point.up.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .padding(20)
                            .background(Circle().fill(Color.black.opacity(0.4)))
                            .offset(x: -40, y: -100) // Position over left location point
                            .gesture(DragGesture().onChanged { _ in })
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
            
            // Tooltip
            if showTooltip {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add up to 5 locations")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("We'll find the perfect midpoint")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.7))
                        )
                        .padding(.bottom, 100)
                        .padding(.trailing, 20)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // Start demo animation sequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.easeIn(duration: 0.5)) {
                    showFingerTap = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showFingerTap = false
                    }
                    
                    // Show midpoint calculation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            showMidpoint = true
                        }
                        
                        // Show places after midpoint appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                showPlaces = true
                            }
                        }
                        
                        // Show tooltip
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showTooltip = true
                            }
                        }
                    }
                }
            }
        }
        .cornerRadius(16)
        .padding(.horizontal, 24)
        .aspectRatio(1.0, contentMode: .fit)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
    
    // Example places near the midpoint
    private var demoPlaces: [DemoPlace] {
        [
            DemoPlace(id: 1, 
                     coordinate: CLLocationCoordinate2D(latitude: 37.7708, longitude: -122.3457),
                     name: "Restaurant", 
                     category: .restaurant),
            DemoPlace(id: 2, 
                     coordinate: CLLocationCoordinate2D(latitude: 37.7738, longitude: -122.3337),
                     name: "Cafe", 
                     category: .cafe),
            DemoPlace(id: 3, 
                     coordinate: CLLocationCoordinate2D(latitude: 37.7678, longitude: -122.3407),
                     name: "Park", 
                     category: .park)
        ]
    }
}

struct DemoLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
    let color: Color
}

enum DemoPlaceCategory {
    case restaurant, cafe, park
    
    var color: Color {
        switch self {
        case .restaurant: return .orange
        case .cafe: return .brown
        case .park: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .park: return "leaf.fill"
        }
    }
}

struct DemoPlace: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let name: String
    let category: DemoPlaceCategory
}

struct PlacePin: View {
    let place: DemoPlace
    let coordToScreenX: (CLLocationCoordinate2D) -> CGFloat
    let coordToScreenY: (CLLocationCoordinate2D) -> CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 34, height: 34)
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            
            Circle()
                .fill(place.category.color)
                .frame(width: 28, height: 28)
            
            Image(systemName: place.category.icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
        .position(
            x: coordToScreenX(place.coordinate),
            y: coordToScreenY(place.coordinate)
        )
    }
}

struct MapDemonstrationView_Previews: PreviewProvider {
    static var previews: some View {
        MapDemonstrationView()
            .frame(height: 300)
            .padding()
    }
} 