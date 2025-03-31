import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: Place
    let locations: [Location]
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab = 0
    
    // For backwards compatibility
    init(place: Place, location1: Location?, location2: Location?) {
        self.place = place
        self.locations = [location1, location2].compactMap { $0 }
    }
    
    // New initializer supporting multiple locations
    init(place: Place, locations: [Location]) {
        self.place = place
        self.locations = locations
    }
    
    // Mock data for display purposes
    @State private var rating: Double = Double.random(in: 3.5...4.9)
    @State private var reviewCount: Int = Int.random(in: 15...120)
    @State private var isOpen: Bool = Bool.random()
    @State private var hours: String = "\(Int.random(in: 7...11)):00 - \(Int.random(in: 20...23)):00"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with place name and top controls
                VStack(spacing: 4) {
                    // Place name and close button
                    HStack {
                        Text(place.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                addToFavorites()
                            }) {
                                Image(systemName: "plus")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color(UIColor.tertiarySystemBackground)))
                            }
                            
                            Button(action: {
                                sharePlace()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color(UIColor.tertiarySystemBackground)))
                            }
                            
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color(UIColor.tertiarySystemBackground)))
                            }
                        }
                    }
                    
                    // Subtitle (category or address)
                    HStack {
                        if let subtitleText = place.mapItem.placemark.thoroughfare {
                            Text(subtitleText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text(place.category.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Quick action buttons (like Apple Maps)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Transport times buttons for each location
                        ForEach(0..<min(locations.count, 3), id: \.self) { index in
                            VStack {
                                ZStack {
                                    Circle()
                                        .fill(locationColor(for: index))
                                        .frame(width: 60, height: 60)
                                    
                                    VStack(spacing: 0) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        // Show driving time using the new method
                                        let travelTime = place.getTravelTime(forLocationIndex: index)
                                        if let drivingTime = travelTime.driving {
                                            Text("\(drivingTime) min")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                
                                Text(locations[index].name.split(separator: ",").first.map(String.init) ?? "Location \(index + 1)")
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }
                        }
                        
                        // Call button
                        ActionButton(title: "Call", icon: "phone", action: makeCall)
                        
                        // Website button
                        ActionButton(title: "Website", icon: "safari", action: openWebsite)
                        
                        // Menu button
                        ActionButton(title: "Menu", icon: "doc.text", action: openMenu)
                        
                        // More button
                        ActionButton(title: "More", icon: "ellipsis", action: showMoreOptions)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                Divider()
                    .padding(.top, 8)
                
                // Information tabs (similar to Apple Maps)
                VStack(spacing: 0) {
                    // Tab buttons
                    HStack(spacing: 0) {
                        TabButton(title: "HOURS", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }
                        
                        TabButton(title: "RATINGS", isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }
                        
                        TabButton(title: "DISTANCE", isSelected: selectedTab == 2) {
                            selectedTab = 2
                        }
                    }
                    
                    // Tab content based on selection
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedTab == 0 {
                            // Hours tab
                            HStack {
                                Text(isOpen ? "Open" : "Closed")
                                    .foregroundColor(isOpen ? .green : .red)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text(hours)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        } else if selectedTab == 1 {
                            // Ratings tab
                            HStack(spacing: 8) {
                                RatingStars(rating: rating)
                                
                                Text(String(format: "%.1f", rating))
                                    .fontWeight(.medium)
                                
                                Text("(\(reviewCount))")
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Open ratings site
                                }) {
                                    Text("Rate")
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        } else {
                            // Distance tab
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.gray)
                                
                                Text(formatDistance(place.distanceFromMidpoint))
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Button(action: {
                                    openInMaps()
                                }) {
                                    Text("Directions")
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Divider()
                
                // Map showing the place
                PlaceMapView(place: place, locations: locations)
                    .frame(height: 220)
                    .padding(.top, 8)
                
                // Image mockup (would be actual images in real implementation)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Photos")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(1...3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 160, height: 120)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Reviews section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Ratings & Reviews")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            // Open full reviews
                        }) {
                            Text("See All")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Rating summary
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 36, weight: .bold))
                            
                            RatingStars(rating: rating)
                                .frame(height: 20)
                            
                            Text("\(reviewCount) ratings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 100)
                        
                        // Mock review
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                RatingStars(rating: 4.0)
                                    .frame(height: 16)
                                
                                Spacer()
                                
                                Text("2 months ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Visited and really enjoyed the atmosphere. The food was delicious and service was great.")
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Travel information section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Travel Times")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    // Distance card with improved styling
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Distance from midpoint")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(formatDistance(place.distanceFromMidpoint))
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Dynamically show travel times for all locations
                    ForEach(0..<locations.count, id: \.self) { index in
                        let location = locations[index]
                        let travelTime = place.getTravelTime(forLocationIndex: index)
                        
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(locationColor(for: index))
                                    .frame(width: 32, height: 32)
                                
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("From \(location.name)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                HStack(spacing: 16) {
                                    if let drivingTime = travelTime.driving {
                                        Label("\(drivingTime) min", systemImage: "car.fill")
                                            .foregroundColor(.secondary)
                                            .font(.subheadline)
                                    }
                                    
                                    if let walkingTime = travelTime.walking {
                                        Label("\(walkingTime) min", systemImage: "figure.walk")
                                            .foregroundColor(.secondary)
                                            .font(.subheadline)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                // Details section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Details")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    VStack(spacing: 0) {
                        // Hours row
                        DetailRow(icon: "clock", title: "Hours", value: hours) {
                            // View hours action
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Website row
                        DetailRow(icon: "safari", title: "Website", value: "Visit Website") {
                            openWebsite()
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Phone row
                        DetailRow(icon: "phone", title: "Phone", value: "+1 (555) 123-4567") {
                            makeCall()
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Address row
                        DetailRow(icon: "mappin", title: "Address", value: place.mapItem.placemark.thoroughfare ?? "View Address") {
                            // View on map
                        }
                    }
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        openInMaps()
                    }) {
                        HStack {
                            Image(systemName: "car.fill")
                            Text("Directions")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                        )
                        .foregroundColor(.white)
                    }
                    
                    // Display different transit options
                    HStack(spacing: 20) {
                        TransitButton(icon: "car.fill", title: "Drive") {
                            openInMaps(mode: "MKLaunchOptionsDirectionsModeDriving")
                        }
                        
                        TransitButton(icon: "figure.walk", title: "Walk") {
                            openInMaps(mode: "MKLaunchOptionsDirectionsModeWalking")
                        }
                        
                        TransitButton(icon: "bus.fill", title: "Transit") {
                            openInMaps(mode: "MKLaunchOptionsDirectionsModeTransit")
                        }
                        
                        TransitButton(icon: "bicycle", title: "Cycle") {
                            openInMaps(mode: "MKLaunchOptionsDirectionsModeOther")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            let distanceInKm = distance / 1000
            return String(format: "%.1f km", distanceInKm)
        }
    }
    
    private func openInMaps(mode: String = "MKLaunchOptionsDirectionsModeDriving") {
        let options = [
            MKLaunchOptionsDirectionsModeKey: mode
        ]
        
        place.mapItem.openInMaps(launchOptions: options)
    }
    
    private func sharePlace() {
        let message = "Hey! Let's meet at \(place.name). I found this spot on Halfway - it's right in the middle between us!"
        
        // Create activity items including location coordinates for sharing
        let items: [Any] = [message]
        
        // Create and present the activity view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        rootViewController.present(activityViewController, animated: true, completion: nil)
    }
    
    private func makeCall() {
        guard let phoneNumber = place.mapItem.phoneNumber else { return }
        
        let cleanedPhoneNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
                                        .replacingOccurrences(of: "-", with: "")
                                        .replacingOccurrences(of: "(", with: "")
                                        .replacingOccurrences(of: ")", with: "")
        
        if let url = URL(string: "tel://\(cleanedPhoneNumber)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWebsite() {
        guard let url = place.mapItem.url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    private func openMenu() {
        // Mock - would open menu URL if available
    }
    
    private func showMoreOptions() {
        // Would show additional options
    }
    
    private func addToFavorites() {
        // Would add to favorites
    }
    
    // Helper function to get color based on location index
    func locationColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink]
        return index < colors.count ? colors[index] : .gray
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 3)
            }
        }
    }
}

struct RatingStars: View {
    let rating: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= Int(rating) ? "star.fill" : 
                               (Double(index) - 0.5 <= rating ? "star.leadinghalf.filled" : "star"))
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .frame(width: 28)
                    .padding(.leading, 16)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
        }
    }
}

struct TransitButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct PlaceMapView: View {
    let place: Place
    let locations: [Location]
    
    // For backward compatibility
    init(place: Place, location1: Location?, location2: Location?) {
        self.place = place
        self.locations = [location1, location2].compactMap { $0 }
    }
    
    // New initializer for multiple locations
    init(place: Place, locations: [Location]) {
        self.place = place
        self.locations = locations
    }
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: makeAnnotationItems()) { item in
            MapAnnotation(coordinate: item.coordinate) {
                if item.isPlace {
                    PlaceAnnotationView(place: place)
                } else {
                    LocationAnnotationView(index: item.index)
                }
            }
        }
        .onAppear {
            calculateRegion()
        }
    }
    
    // Create a unified annotation item list
    private func makeAnnotationItems() -> [AnnotationItem] {
        var items = [AnnotationItem]()
        
        // Add place as annotation
        items.append(AnnotationItem(
            id: "place",
            coordinate: place.coordinate,
            isPlace: true, 
            index: -1
        ))
        
        // Add locations as annotations
        for (index, location) in locations.enumerated() {
            items.append(AnnotationItem(
                id: "location_\(index)",
                coordinate: location.coordinate,
                isPlace: false,
                index: index
            ))
        }
        
        return items
    }
    
    private func calculateRegion() {
        // Start with the place
        var coordinates = [place.coordinate]
        
        // Add all locations
        coordinates.append(contentsOf: locations.map { $0.coordinate })
        
        // Calculate the center and span to include all points
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Add some padding
        let latDelta = max(0.05, (maxLat - minLat) * 1.5)
        let lonDelta = max(0.05, (maxLon - minLon) * 1.5)
        
        region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
}

// Custom annotation for a place
struct PlaceAnnotationView: View {
    let place: Place
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor(named: place.category.color) ?? .gray))
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            Image(systemName: place.category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// Custom annotation for a location
struct LocationAnnotationView: View {
    let index: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(locationColor(for: index))
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            Text("\(index + 1)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // Helper function to get color based on location index
    private func locationColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink]
        return index < colors.count ? colors[index] : .gray
    }
}

// Helper model for unified map annotations
struct AnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isPlace: Bool
    let index: Int
} 