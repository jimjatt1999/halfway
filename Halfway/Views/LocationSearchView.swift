import SwiftUI
import MapKit
import Combine

struct LocationSearchView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String
    @State private var searchResults: [Location] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var showRecentSearches = true
    
    // Store recent searches for faster selection
    @State private var recentSearches: [Location] = []
    
    var onLocationSelected: (Location) -> Void
    var onUseCurrentLocation: () -> Void
    
    init(searchText: String, onLocationSelected: @escaping (Location) -> Void, onUseCurrentLocation: @escaping () -> Void) {
        _searchText = State(initialValue: searchText)
        self.onLocationSelected = onLocationSelected
        self.onUseCurrentLocation = onUseCurrentLocation
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack {
                Button(action: {
                    // Cancel any pending search before dismissing
                    searchTask?.cancel()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
                
                // Improved search field with debouncing for optimal performance
                TextField("Search for a location", text: $searchText)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.leading, 4)
                    .autocorrectionDisabled(true)
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { newValue in
                        // Only show recent searches when search text is empty
                        showRecentSearches = newValue.isEmpty
                        
                        if !newValue.isEmpty {
                            // Cancel previous search if any
                            searchTask?.cancel()
                            
                            // Optimized debounce for smoother performance
                            searchTask = Task {
                                // Short delay to avoid excessive searches while typing
                                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        performSearch(query: newValue)
                                    }
                                }
                            }
                        } else {
                            searchResults = []
                        }
                    }
                
                // Add a clear button if there's text
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        showRecentSearches = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            // Current location button
            Button(action: {
                onUseCurrentLocation()
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Use Current Location")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 10)
            }
            
            // Divider
            Divider()
                .padding(.top, 10)
            
            // Loading indicator
            if isSearching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            }
            
            // Recent searches section - enhanced design
            if showRecentSearches && !recentSearches.isEmpty && !isSearching {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Searches")
                            .font(.headline)
                            .padding(.leading)
                            .padding(.top, 10)
                        
                        Spacer()
                        
                        // Add a clear all button
                        Button(action: {
                            withAnimation {
                                recentSearches = []
                                UserDefaults.standard.removeObject(forKey: "recentSearches")
                            }
                        }) {
                            Text("Clear All")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.trailing)
                        .padding(.top, 10)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            ForEach(recentSearches, id: \.self) { location in
                                Button(action: {
                                    // Move this location to the top of recents
                                    saveToRecentSearches(location) 
                                    onLocationSelected(location)
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    LocationRow(location: location, isRecent: true)
                                        .contextMenu {
                                            Button(role: .destructive, action: {
                                                withAnimation {
                                                    if let index = recentSearches.firstIndex(where: { $0.name == location.name }) {
                                                        recentSearches.remove(at: index)
                                                        saveRecentSearchesToUserDefaults()
                                                    }
                                                }
                                            }) {
                                                Label("Remove from History", systemImage: "trash")
                                            }
                                        }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } 
            // Search results
            else if !showRecentSearches || isSearching {
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(searchResults, id: \.self) { location in
                            Button(action: {
                                // Add to recent searches when selected
                                saveToRecentSearches(location)
                                onLocationSelected(location)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                LocationRow(location: location)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .navigationBarHidden(true)
        .onAppear {
            // Load recent searches from UserDefaults
            loadRecentSearches()
        }
    }
    
    private func performSearch(query: String) {
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // Use all available result types for comprehensive search results
        request.resultTypes = [.pointOfInterest, .address]
        
        // Try to use user's current location for better regional results with a more appropriate radius
        var userRegion: MKCoordinateRegion?
        if let userLocation = CLLocationManager().location?.coordinate {
            // Start with a smaller radius for more relevant nearby results
            let localRadius: CLLocationDistance = 20000 // 20km for local results
            userRegion = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: localRadius,
                longitudinalMeters: localRadius
            )
        }
        
        // Use user location if available, otherwise use a default region
        // Choose a more central global default location for better worldwide results
        let defaultLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let defaultRegion = MKCoordinateRegion(
            center: defaultLocation,
            latitudinalMeters: 150000, // 150km radius - wider for better coverage
            longitudinalMeters: 150000
        )
        
        request.region = userRegion ?? defaultRegion
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            guard let response = response, error == nil else {
                // If search fails with the tighter local radius, try with a wider radius
                if let userLocation = CLLocationManager().location?.coordinate, userRegion != nil {
                    let widerRequest = MKLocalSearch.Request()
                    widerRequest.naturalLanguageQuery = query
                    widerRequest.resultTypes = [.pointOfInterest, .address]
                    widerRequest.region = MKCoordinateRegion(
                        center: userLocation,
                        latitudinalMeters: 100000, // 100km radius for fallback
                        longitudinalMeters: 100000
                    )
                    
                    let widerSearch = MKLocalSearch(request: widerRequest)
                    widerSearch.start { widerResponse, widerError in
                        if let widerResponse = widerResponse, widerError == nil {
                            processSearchResults(widerResponse)
                        } else {
                            searchResults = []
                        }
                    }
                } else {
                    searchResults = []
                }
                return
            }
            
            processSearchResults(response)
        }
    }
    
    // Improve the processSearchResults function to extract better location names
    private func processSearchResults(_ response: MKLocalSearch.Response) {
        // Process and format search results with better ranking
        var results: [Location] = []
        
        for item in response.mapItems {
            let placemark = item.placemark
            
            // Enhance location name extraction to be more complete
            var name = "Unknown Location"
            
            // First priority: Use the point of interest name if available
            if let itemName = item.name, !itemName.isEmpty && itemName != "Current Location" {
                name = itemName
            }
            // Second priority: Use a formatted address for addresses without names
            else {
                // Create a more detailed address-based name
                var addressComponents: [String] = []
                
                // Add street address if available
                if let subThoroughfare = placemark.subThoroughfare, let thoroughfare = placemark.thoroughfare {
                    addressComponents.append("\(subThoroughfare) \(thoroughfare)")
                } else if let thoroughfare = placemark.thoroughfare {
                    addressComponents.append(thoroughfare)
                }
                
                // Add additional components for better identification
                if let locality = placemark.locality {
                    if addressComponents.isEmpty {
                        // If no street address, make locality primary
                        name = locality
                    } else {
                        // Otherwise add it to the address components
                        addressComponents.append(locality)
                    }
                }
                
                // Only generate an address-based name if we have components and name is still the default
                if !addressComponents.isEmpty && name == "Unknown Location" {
                    name = addressComponents.joined(separator: ", ")
                }
            }
            
            // Calculate a relevance score to rank results better
            var relevanceScore = 0
            
            // Prioritize results with more complete information
            if item.name != nil && !item.name!.isEmpty { relevanceScore += 5 }  // Increased weight
            if placemark.thoroughfare != nil { relevanceScore += 3 }  // Increased weight
            if placemark.subThoroughfare != nil { relevanceScore += 2 }  // Added subThoroughfare
            if placemark.locality != nil { relevanceScore += 3 }  // Increased weight
            if placemark.administrativeArea != nil { relevanceScore += 2 }
            if placemark.country != nil { relevanceScore += 1 }
            
            // Prefer places with phone numbers or websites (likely to be actual businesses)
            if item.phoneNumber != nil { relevanceScore += 3 }  // Increased weight
            if item.url != nil { relevanceScore += 3 }  // Increased weight
            
            // Add debug logging to see what we're getting
            print("Location result: '\(name)' (Score: \(relevanceScore))")
            if let poi = item.pointOfInterestCategory?.rawValue {
                print("  - Category: \(poi)")
            }
            
            // Create location with the relevance score for sorting
            let location = Location(
                name: name,
                placemark: placemark,
                coordinate: placemark.coordinate,
                relevanceScore: relevanceScore
            )
            
            // Generate a much more detailed subtitle
            var subtitleComponents: [String] = []
            
            // Add category first if available
            if let pointOfInterestCategory = item.pointOfInterestCategory {
                let categoryName = pointOfInterestCategoryName(pointOfInterestCategory)
                if !categoryName.isEmpty {
                    subtitleComponents.append(categoryName)
                    // Also boost score for categorized places
                    location.relevanceScore += 3
                }
            }
            
            // Add address details if not already in the name
            let address = formatDetailedAddress(from: placemark)
            if !address.isEmpty && !name.contains(address) {
                if !subtitleComponents.isEmpty {
                    subtitleComponents.append("•")
                }
                subtitleComponents.append(address)
            }
            
            // Set the subtitle
            if !subtitleComponents.isEmpty {
                location.subtitle = subtitleComponents.joined(separator: " ")
            }
            
            // Set additional details for the location
            location.phoneNumber = item.phoneNumber
            location.website = item.url
            
            results.append(location)
        }
        
        // Sort by relevance score (higher first) and limit results
        results.sort { $0.relevanceScore > $1.relevanceScore }
        
        // Limit results but ensure we have enough high-quality ones
        searchResults = Array(results.prefix(20))
    }
    
    // Enhance the formatDetailedAddress function to create better address strings
    private func formatDetailedAddress(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        // For addresses without street numbers, prioritize locality
        if placemark.thoroughfare == nil {
            // Skip to city/state level details
            if let locality = placemark.locality {
                components.append(locality)
            }
            
            if let administrativeArea = placemark.administrativeArea {
                components.append(administrativeArea)
            }
            
            return components.joined(separator: ", ")
        }
        
        // For addresses with street information, include that too
        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                components.append(thoroughfare)
            }
        }
        
        // Add locality (city)
        if let locality = placemark.locality {
            components.append(locality)
        } else if let subAdministrativeArea = placemark.subAdministrativeArea {
            // Fallback to county/district if no city is available
            components.append(subAdministrativeArea)
        }
        
        // Add administrative area (state/province)
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        // Join components with commas
        return components.joined(separator: ", ")
    }
    
    // Helper function to get a human-readable name for point of interest categories
    private func pointOfInterestCategoryName(_ category: MKPointOfInterestCategory) -> String {
        switch category {
        case .airport: return "Airport"
        case .amusementPark: return "Amusement Park"
        case .aquarium: return "Aquarium"
        case .atm: return "ATM"
        case .bakery: return "Bakery"
        case .bank: return "Bank"
        case .beach: return "Beach"
        case .brewery: return "Brewery"
        case .cafe: return "Café"
        case .campground: return "Campground"
        case .carRental: return "Car Rental"
        case .evCharger: return "EV Charger"
        case .fireStation: return "Fire Station"
        case .fitnessCenter: return "Fitness Center"
        case .foodMarket: return "Food Market"
        case .gasStation: return "Gas Station"
        case .hospital: return "Hospital"
        case .hotel: return "Hotel"
        case .laundry: return "Laundry"
        case .library: return "Library"
        case .marina: return "Marina"
        case .movieTheater: return "Movie Theater"
        case .museum: return "Museum"
        case .nationalPark: return "National Park"
        case .nightlife: return "Nightlife"
        case .park: return "Park"
        case .parking: return "Parking"
        case .pharmacy: return "Pharmacy"
        case .police: return "Police Station"
        case .postOffice: return "Post Office"
        case .publicTransport: return "Public Transit"
        case .restaurant: return "Restaurant"
        case .restroom: return "Restroom"
        case .school: return "School"
        case .stadium: return "Stadium"
        case .store: return "Store"
        case .theater: return "Theater"
        case .university: return "University"
        case .winery: return "Winery"
        case .zoo: return "Zoo"
        default: return ""
        }
    }
    
    // Save to recent searches
    private func saveToRecentSearches(_ location: Location) {
        // Ensure we don't add duplicates
        if !recentSearches.contains(where: { $0.name == location.name }) {
            var newRecents = recentSearches
            newRecents.insert(location, at: 0)
            
            // Keep only the 5 most recent searches
            if newRecents.count > 5 {
                newRecents = Array(newRecents.prefix(5))
            }
            
            recentSearches = newRecents
            
            // Save to UserDefaults
            saveRecentSearchesToUserDefaults()
        }
    }
    
    // Load recent searches from UserDefaults
    private func loadRecentSearches() {
        guard let data = UserDefaults.standard.data(forKey: "recentSearches") else { return }
        
        do {
            // Use NSSecureCoding API
            let decoded = try NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: Location.self, from: data)
            recentSearches = decoded ?? []
        } catch {
            print("Failed to load recent searches: \(error)")
            recentSearches = []
        }
    }
    
    // Save recent searches to UserDefaults
    private func saveRecentSearchesToUserDefaults() {
        do {
            // Use NSSecureCoding API
            let data = try NSKeyedArchiver.archivedData(withRootObject: recentSearches, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: "recentSearches")
        } catch {
            print("Failed to save recent searches: \(error)")
        }
    }
}

struct LocationRow: View {
    let location: Location
    var isRecent: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon - different for recent vs search result
            ZStack {
                Circle()
                    .fill(isRecent ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: isRecent ? "clock" : "mappin.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isRecent ? .blue : .gray)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(location.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Show either the custom subtitle or formatted address
                if let subtitle = location.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    // Format address as backup
                    let address = formatDetailedAddress(from: location.placemark)
                    if !address.isEmpty {
                        Text(address)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Small chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .opacity(0.6)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
    
    // More detailed address formatting
    private func formatDetailedAddress(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        // For addresses without street numbers, prioritize locality
        if placemark.thoroughfare == nil {
            // Skip to city/state level details
            if let locality = placemark.locality {
                components.append(locality)
            }
            
            if let administrativeArea = placemark.administrativeArea {
                components.append(administrativeArea)
            }
            
            return components.joined(separator: ", ")
        }
        
        // For addresses with street information, include that too
        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                components.append(thoroughfare)
            }
        }
        
        // Add locality (city)
        if let locality = placemark.locality {
            components.append(locality)
        } else if let subAdministrativeArea = placemark.subAdministrativeArea {
            // Fallback to county/district if no city is available
            components.append(subAdministrativeArea)
        }
        
        // Add administrative area (state/province)
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        // Join components with commas
        return components.joined(separator: ", ")
    }
} 