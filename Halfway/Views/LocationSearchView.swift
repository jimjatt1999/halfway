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
        
        // Use available result types for better search results
        request.resultTypes = [.pointOfInterest, .address]
        
        // Try to use user's current location for better regional results
        var userRegion: MKCoordinateRegion?
        if let userLocation = CLLocationManager().location?.coordinate {
            userRegion = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 50000, // 50km radius
                longitudinalMeters: 50000
            )
        }
        
        // Use user location if available, otherwise use a default region
        let defaultLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let defaultRegion = MKCoordinateRegion(
            center: defaultLocation,
            latitudinalMeters: 100000, // 100km radius
            longitudinalMeters: 100000
        )
        
        request.region = userRegion ?? defaultRegion
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            guard let response = response, error == nil else {
                searchResults = []
                return
            }
            
            // Process and format search results better
            var results: [Location] = []
            
            for item in response.mapItems {
                let placemark = item.placemark
                
                // Create a better name for the location
                var name = item.name ?? "Unknown Location"
                
                // If it's just an address with no name, use the formatted address as the name
                if name == "Unknown Location" || name.isEmpty {
                    name = formatAddress(from: placemark)
                }
                
                let location = Location(
                    name: name,
                    placemark: placemark,
                    coordinate: placemark.coordinate
                )
                
                results.append(location)
            }
            
            // Limit results but ensure we have enough high-quality ones
            searchResults = Array(results.prefix(15))
        }
    }
    
    // Helper to format address better
    private func formatAddress(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        // Add street number and name if available
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        // Format the first part of the address (street)
        let street = components.joined(separator: " ")
        components.removeAll()
        
        if !street.isEmpty {
            components.append(street)
        }
        
        // Add locality and administrative area
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        // Join all components
        let result = components.joined(separator: ", ")
        return result.isEmpty ? "Unknown Location" : result
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
        HStack(spacing: 16) {
            // More visually distinct icon
            ZStack {
                Circle()
                    .fill(isRecent ? Color.blue.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: isRecent ? "clock.fill" : "mappin.circle.fill")
                    .foregroundColor(isRecent ? .blue : .red)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Main location name
                Text(location.name)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                // More detailed secondary information
                HStack(spacing: 3) {
                    // Show detailed address components when available
                    if let locality = location.placemark.locality {
                        if let thoroughfare = location.placemark.thoroughfare {
                            // Show both street and city
                            if let subThoroughfare = location.placemark.subThoroughfare {
                                Text("\(subThoroughfare) \(thoroughfare), \(locality)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("\(thoroughfare), \(locality)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            // Just show city
                            Text(locality)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else if let administrativeArea = location.placemark.administrativeArea {
                        // Fallback to state/province
                        Text(administrativeArea)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Add a chevron for better visual indication that this is tappable
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.gray)
                .opacity(0.7)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(Color.clear) // Clear background
    }
} 