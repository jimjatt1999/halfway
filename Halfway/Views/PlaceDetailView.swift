import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: Place
    let locations: [Location]
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab = 0
    @State private var showShareToast = false
    
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
                        
                        // Only show Call button if phone number is available
                        if place.mapItem.phoneNumber != nil {
                            ActionButton(title: "Call", icon: "phone", action: makeCall)
                        }
                        
                        // Only show Website button if URL is available
                        if place.mapItem.url != nil {
                            ActionButton(title: "Website", icon: "safari", action: openWebsite)
                        }
                        
                        // Only show Menu button for restaurants, cafes and bars
                        if place.category == .restaurant || place.category == .cafe || place.category == .bar {
                            ActionButton(title: "Menu", icon: "doc.text", action: openMenu)
                        }
                        
                        // Share button
                        ActionButton(title: "Share", icon: "square.and.arrow.up", action: shareLocation)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                Divider()
                    .padding(.top, 8)
                
                // Information tab - only show distance since that's reliable data
                VStack(spacing: 0) {
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
                    .padding(.vertical, 12)
                }
                
                Divider()
                
                // Map showing the place
                PlaceMapView(place: place, locations: locations)
                    .frame(height: 220)
                    .padding(.top, 8)
                
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
                
                // Details section - only show data we can reliably get
                VStack(alignment: .leading, spacing: 16) {
                    Text("Details")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    VStack(spacing: 0) {
                        // Website row - only if available
                        if place.mapItem.url != nil {
                            DetailRow(icon: "safari", title: "Website", value: "Visit Website") {
                                openWebsite()
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                        }
                        
                        // Phone row - only if available
                        if let phoneNumber = place.mapItem.phoneNumber {
                            DetailRow(icon: "phone", title: "Phone", value: phoneNumber) {
                                makeCall()
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                        }
                        
                        // Address row - combine all available address components
                        DetailRow(icon: "mappin", title: "Address", value: formatAddress()) {
                            shareLocation()
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
                    
                    // Share location button
                    Button(action: {
                        shareLocation()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Location")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.tertiarySystemBackground))
                        )
                        .foregroundColor(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
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
        .overlay(
            // Toast message when location is copied
            VStack {
                Spacer()
                
                if showShareToast {
                    Text("Location copied to clipboard")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .transition(.move(edge: .bottom))
                        .padding(.bottom, 30)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showShareToast)
        )
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            let distanceInKm = distance / 1000
            return String(format: "%.1f km", distanceInKm)
        }
    }
    
    private func formatAddress() -> String {
        let placemark = place.mapItem.placemark
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let subThoroughfare = placemark.subThoroughfare {
            // Insert at beginning if it's a number
            if Int(subThoroughfare) != nil && !components.isEmpty {
                components[0] = "\(subThoroughfare) \(components[0])"
            } else {
                components.append(subThoroughfare)
            }
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        return components.isEmpty ? "View Address" : components.joined(separator: ", ")
    }
    
    private func openInMaps(mode: String = "MKLaunchOptionsDirectionsModeDriving") {
        let options = [
            MKLaunchOptionsDirectionsModeKey: mode
        ]
        
        place.mapItem.openInMaps(launchOptions: options)
    }
    
    private func shareLocation() {
        // Create message with place details
        var shareText = "I found this location on Halfway! Let's meet at: "
        
        // Add place name and address if available
        shareText += "\n\n\(place.name)"
        
        let address = formatAddress()
        if address != "View Address" {
            shareText += "\n\(address)"
        }
        
        // Add travel times
        shareText += "\n\nTravel times:"
        for (index, location) in locations.enumerated() {
            let travelTime = place.getTravelTime(forLocationIndex: index)
            var travelInfo = ""
            
            if let drivingTime = travelTime.driving {
                travelInfo += "\(drivingTime) min by car"
            }
            
            if let walkingTime = travelTime.walking {
                if !travelInfo.isEmpty {
                    travelInfo += ", "
                }
                travelInfo += "\(walkingTime) min walking"
            }
            
            if !travelInfo.isEmpty {
                shareText += "\n- From \(location.name): \(travelInfo)"
            }
        }
        
        // Copy to clipboard
        UIPasteboard.general.string = shareText
        
        // Show toast
        withAnimation {
            showShareToast = true
        }
        
        // Hide toast after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showShareToast = false
            }
        }
    }
    
    private func makeCall() {
        if let phoneNumber = place.mapItem.phoneNumber {
            let formattedNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
            if let url = URL(string: "tel://\(formattedNumber)"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWebsite() {
        if let url = place.mapItem.url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openMenu() {
        // Would open menu URL if available
    }
    
    private func showMoreOptions() {
        // Would show additional options
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
    
    @State private var isAvailable: Bool = true
    
    // Determine availability based on place data and button type
    init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        
        // Set initial availability state based on context
        switch icon {
        case "phone":
            // Phone button should be disabled if no phone number
            _isAvailable = State(initialValue: title == "Call" ? UIApplication.shared.canOpenURL(URL(string: "tel://123456789")!) : true)
        case "safari":
            // Website button should be disabled if no website
            _isAvailable = State(initialValue: title == "Website" ? UIApplication.shared.canOpenURL(URL(string: "https://apple.com")!) : true)
        case "doc.text":
            // Menu button should be disabled for non-food places
            _isAvailable = State(initialValue: true)
        default:
            _isAvailable = State(initialValue: true)
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isAvailable ? .blue : .gray)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isAvailable ? .primary : .secondary)
            }
        }
        .opacity(isAvailable ? 1.0 : 0.5)
        .disabled(!isAvailable)
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