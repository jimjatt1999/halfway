import SwiftUI
import MapKit

struct MainView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel: HalfwayViewModel
    
    @State private var isLocationSearching = false
    @State private var searchFor: Int = 1 // 1 for location1, 2 for location2
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to SF, will update to user location
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showingErrorAlert = false
    @State private var isExpanded = false
    @State private var resetLocations = false
    @State private var mapType: MKMapType = .standard
    @State private var draggedOffset: CGFloat = 0
    
    // Minimum height for the results panel - increased for better initial visibility
    let minDragHeight: CGFloat = 550 // Changed from 450 to 550 for more screen coverage initially
    // Maximum height for the results panel (will be calculated from screen height)
    var maxDragHeight: CGFloat {
        UIScreen.main.bounds.height * 0.85
    }
    
    init() {
        let vm = HalfwayViewModel(locationManager: LocationManager())
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        ZStack {
            // Map view with blur overlay when results are shown
            MapView(region: $mapRegion, 
                    location1: viewModel.location1, 
                    location2: viewModel.location2, 
                    midpoint: viewModel.midpoint,
                    places: viewModel.places,
                    searchRadius: viewModel.searchRadius,
                    selectedPlace: $viewModel.showingPlaceDetail,
                    isExpanded: isExpanded,
                    resetLocations: $resetLocations,
                    mapType: mapType)
                .edgesIgnoringSafeArea(.all)
            
            // Semi-transparent overlay when results are shown (creates subtle depth)
            if !isExpanded && !viewModel.places.isEmpty {
                Color.black.opacity(0.15)
                    .edgesIgnoringSafeArea(.all)
            }
            
            if !isExpanded {
                VStack(spacing: 0) {
                    // App title and control buttons
                    HStack {
                        Text("Halfway")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.leading)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // Expand button
                            Button(action: {
                                withAnimation(.spring(duration: 0.3)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.indigo)
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            // Only show reset button when locations exist
                            // Remove the search icon as requested - only show expand and reset buttons
                            if viewModel.location1 != nil || viewModel.location2 != nil {
                                Button(action: {
                                    withAnimation {
                                        resetLocations = true
                                        viewModel.clearLocation1()
                                        viewModel.clearLocation2()
                                        viewModel.places = []
                                    }
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(Color.indigo)
                                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                        )
                                }
                            }
                        }
                        .padding(.trailing)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Content panel at the bottom
                    if viewModel.midpoint == nil || viewModel.places.isEmpty {
                        // Redesigned floating search panel
                        searchPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Improved results panel
                        ResultsPanel(
                            viewModel: viewModel,
                            resetLocations: $resetLocations,
                            mapRegion: $mapRegion,
                            isExpanded: $isExpanded,
                            dragOffset: $draggedOffset,
                            minHeight: minDragHeight,
                            maxHeight: maxDragHeight,
                            mapType: mapType
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
            } else {
                // Expanded mode with compact controls
                VStack {
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // Map type toggle button
                            Button(action: {
                                mapType = mapType == .standard ? .satellite : .standard
                            }) {
                                Image(systemName: mapType == .standard ? "globe" : "map")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.indigo)
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            // Reset button
                            Button(action: {
                                withAnimation {
                                    resetLocations = true
                                    viewModel.clearLocation1()
                                    viewModel.clearLocation2()
                                    viewModel.places = []
                                    
                                    // Return to search view when clearing
                                    isExpanded = false
                                }
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.indigo)
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            // Collapse button
                            Button(action: {
                                withAnimation(.spring(duration: 0.3)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.indigo)
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                        }
                        .padding(.trailing)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
            
            // Overlay for loading state
            if viewModel.isSearching {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .scaleEffect(2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .sheet(isPresented: $isLocationSearching) {
            LocationSearchView(searchText: "", onLocationSelected: { location in
                if searchFor == 1 {
                    viewModel.setLocation1(location)
                } else {
                    viewModel.setLocation2(location)
                }
                isLocationSearching = false
            }, onUseCurrentLocation: {
                if searchFor == 1 {
                    viewModel.useCurrentLocationFor1()
                } else {
                    viewModel.useCurrentLocationFor2()
                }
                isLocationSearching = false
            })
        }
        .sheet(item: $viewModel.showingPlaceDetail) { place in
            PlaceDetailView(place: place, location1: viewModel.location1, location2: viewModel.location2)
        }
        .alert(viewModel.errorMessage ?? "An error occurred", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        }
        .onChange(of: viewModel.searchRadius) { newValue in
            // Real-time updates for search radius changes
            if !viewModel.places.isEmpty {
                viewModel.searchPlacesAroundMidpoint()
            }
        }
        .onAppear {
            // Set initial map region to user's location if available
            if let userLocation = viewModel.userLocation?.coordinate {
                mapRegion = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
        }
    }
    
    // Redesigned floating search panel
    var searchPanel: some View {
        VStack(spacing: 16) {
            // Modern card design with shadow and blur background
            VStack(spacing: 20) {
                Text("Find places halfway between locations")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                // Location inputs with better styling
                VStack(spacing: 12) {
                    // Location 1
                    locationInputButton(
                        icon: "location.fill",
                        iconColor: .blue,
                        text: viewModel.location1?.name ?? "Enter first location",
                        hasValue: viewModel.location1 != nil,
                        action: {
                            searchFor = 1
                            isLocationSearching = true
                        },
                        clearAction: {
                            viewModel.clearLocation1()
                        }
                    )
                    
                    // Location 2
                    locationInputButton(
                        icon: "figure.stand",
                        iconColor: .green,
                        text: viewModel.location2?.name ?? "Enter second location",
                        hasValue: viewModel.location2 != nil,
                        action: {
                            searchFor = 2
                            isLocationSearching = true
                        },
                        clearAction: {
                            viewModel.clearLocation2()
                        }
                    )
                }
                
                // Find Meeting Places button with improved styling
                Button(action: {
                    viewModel.searchPlacesAroundMidpoint()
                }) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Find Meeting Places")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(viewModel.location1 == nil || viewModel.location2 == nil ? 
                                  Color.indigo.opacity(0.6) : Color.indigo)
                    )
                    .foregroundColor(.white)
                }
                .disabled(viewModel.location1 == nil || viewModel.location2 == nil)
                .animation(.easeInOut(duration: 0.2), value: viewModel.location1 == nil || viewModel.location2 == nil)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 25)
        }
    }
    
    // Reusable location input button with improved styling
    func locationInputButton(icon: String, iconColor: Color, text: String, hasValue: Bool, action: @escaping () -> Void, clearAction: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            Button(action: action) {
                HStack {
                    Text(text)
                        .lineLimit(1)
                        .font(.system(size: 15))
                        .foregroundColor(hasValue ? .primary : .secondary)
                        .padding(.leading, 8)
                    Spacer()
                }
                .contentShape(Rectangle())
                .frame(height: 36)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
            
            if hasValue {
                Button(action: clearAction) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

// Replace ResultsPanel struct with a simpler version without dragging
struct ResultsPanel: View {
    var viewModel: HalfwayViewModel
    @Binding var resetLocations: Bool
    @Binding var mapRegion: MKCoordinateRegion
    @Binding var isExpanded: Bool
    @Binding var dragOffset: CGFloat
    var minHeight: CGFloat
    var maxHeight: CGFloat
    var mapType: MKMapType
    
    @State private var showAllPlaces = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Floating card similar to search panel (not stretched to edges)
            VStack(spacing: 0) {
                // Keep drag indicator for visual consistency but it won't function
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                
                // Results header with count and distance
                HStack {
                    Text("\(viewModel.places.count) places found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let loc1 = viewModel.location1, let loc2 = viewModel.location2 {
                        Spacer()
                        Text(String(format: "%.1f km apart", distance(from: loc1.coordinate, to: loc2.coordinate) / 1000))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                
                // Mini map area to show overview
                ZStack {
                    MapView(region: $mapRegion, 
                            location1: viewModel.location1, 
                            location2: viewModel.location2, 
                            midpoint: viewModel.midpoint,
                            places: viewModel.places, // Show all places on mini map
                            searchRadius: viewModel.searchRadius,
                            selectedPlace: Binding(
                                get: { viewModel.showingPlaceDetail },
                                set: { viewModel.showingPlaceDetail = $0 }
                            ),
                            isExpanded: false,
                            resetLocations: $resetLocations,
                            mapType: mapType)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Overlay text for map expansion with improved visibility
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Tap to expand map")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .padding(12)
                        }
                    }
                }
                .frame(height: 160)
                .contentShape(Rectangle()) // Makes the entire area tappable
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
                
                // Radius slider control with improved styling
                VStack(alignment: .leading) {
                    HStack {
                        Text("Search Radius: \(viewModel.searchRadius, specifier: "%.1f") km")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            // Clear results but keep locations
                            viewModel.places = []
                        }) {
                            Text("Reset Search")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.indigo)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Slider(value: Binding(
                        get: { viewModel.searchRadius },
                        set: { 
                            viewModel.searchRadius = $0
                            // Immediate update when slider changes
                            viewModel.searchPlacesAroundMidpoint()
                        }
                    ), in: 0.5...5.0, step: 0.1)
                        .padding(.horizontal, 20)
                        .accentColor(.indigo)
                }
                .padding(.bottom, 12)
                
                // Category pills with improved styling
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(PlaceCategory.allCases, id: \.self) { category in
                            Button(action: {
                                withAnimation {
                                    if viewModel.selectedCategory == category {
                                        viewModel.filterByCategory(nil)
                                    } else {
                                        viewModel.filterByCategory(category)
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.footnote)
                                    Text(category.rawValue)
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(viewModel.selectedCategory == category ? 
                                              Color(UIColor(named: category.color) ?? .gray) : 
                                              Color(UIColor.secondarySystemBackground))
                                )
                                .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Place list section title with toggle
                HStack {
                    Text("Nearby Places")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if viewModel.places.count > 3 {
                        Button(action: {
                            withAnimation {
                                showAllPlaces.toggle()
                            }
                        }) {
                            Text(showAllPlaces ? "Show Top 3" : "Show All")
                                .font(.subheadline)
                                .foregroundColor(.indigo)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Redesigned place cards with better scrolling
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 16) {
                        if viewModel.places.isEmpty {
                            VStack {
                                Text("No places found matching your criteria")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(viewModel.places.prefix(showAllPlaces ? viewModel.places.count : min(3, viewModel.places.count))) { place in
                                Button(action: {
                                    // Immediately show detail view when tapped
                                    viewModel.showingPlaceDetail = place
                                }) {
                                    ImprovedPlaceCard(place: place, location1: viewModel.location1, location2: viewModel.location2, midpoint: viewModel.midpoint)
                                }
                                .buttonStyle(ScalingButtonStyle()) // Custom button style for better tap feedback
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                // Ensure enough space to see cards
                .frame(minHeight: 250)
            }
            .padding(.horizontal, 20) // Add padding for floating card effect similar to search panel
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
            )
        }
        // Fixed height without dragging
        .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
    }
    
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return from.distance(from: to)
    }
}

// Custom button style for better tap feedback
struct ScalingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// Redesigned Card-style design for place items
struct ImprovedPlaceCard: View {
    let place: Place
    let location1: Location?
    let location2: Location?
    let midpoint: CLLocationCoordinate2D?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Category icon with improved styling
                ZStack {
                    Circle()
                        .fill(Color(UIColor(named: place.category.color) ?? .gray))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: place.category.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Name with better styling
                    Text(place.name)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    
                    // Distance from midpoint with better styling
                    if midpoint != nil {
                        Text("\(formatDistance(place.distanceFromMidpoint)) from midpoint")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                Spacer()
                
                // Chevron indicator for detail
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Travel time section with unified styling for both locations
            HStack(spacing: 0) {
                // Location 1 travel time
                locationTravelTimeView(
                    name: location1?.name ?? "Current Location",
                    drivingTime: place.travelTimeFromLocation1.driving,
                    walkingTime: place.travelTimeFromLocation1.walking,
                    iconColor: .blue
                )
                
                Divider()
                    .frame(height: 24)
                    .background(Color.secondary.opacity(0.3))
                
                // Location 2 travel time
                locationTravelTimeView(
                    name: location2?.name ?? "Current Location",
                    drivingTime: place.travelTimeFromLocation2.driving,
                    walkingTime: place.travelTimeFromLocation2.walking,
                    iconColor: .green
                )
            }
            .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle()) // Make entire card tappable
    }
    
    // Unified travel time view for consistency
    private func locationTravelTimeView(name: String, drivingTime: Int?, walkingTime: Int?, iconColor: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            // Unified styling for location names (including Current Location)
            Text(String(name.prefix(10)))
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                if let driving = drivingTime {
                    LabeledTime(icon: "car.fill", time: "\(driving)m", color: iconColor)
                }
                
                if let walking = walkingTime {
                    LabeledTime(icon: "figure.walk", time: "\(walking)m", color: iconColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.7))
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            let distanceInKm = distance / 1000
            return String(format: "%.1f km", distanceInKm)
        }
    }
}

// Improved component for labeled time values
struct LabeledTime: View {
    let icon: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(time)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// Helper extensions
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
} 