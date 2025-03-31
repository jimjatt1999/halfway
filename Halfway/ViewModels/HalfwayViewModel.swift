import Foundation
import MapKit
import CoreLocation
import Combine

// Direction request type to manage queued direction requests
struct DirectionRequest {
    let placeId: String
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    let transportType: MKDirectionsTransportType
}

class HalfwayViewModel: ObservableObject {
    // MARK: - Properties
    
    // User input properties
    @Published var locations: [Location] = []
    @Published var searchRadius: Double = 1.0 // in kilometers
    @Published var maxSearchRadius: Double = 5.0 // Will be calculated based on locations
    
    // Maximum allowed locations
    private let maxLocations = 5
    
    // Result properties
    @Published var midpoint: CLLocationCoordinate2D?
    @Published var places: [Place] = []
    @Published var filteredPlaces: [Place] = [] // Add filteredPlaces to store search results
    @Published var selectedCategory: PlaceCategory?
    @Published var showingPlaceDetail: Place?
    
    // State properties
    @Published var isSearching: Bool = false
    @Published var searchText: String = ""
    @Published var errorMessage: String?
    
    // Filtered places by category
    private var allPlaces: [Place] = []
    
    // Location manager
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    // Rate limiting control
    private var directionRequestsQueue: [DirectionRequest] = []
    private var isProcessingDirectionRequests = false
    private var timerCancellable: AnyCancellable?
    private var directionRequestThrottleTimer: Timer?
    
    // Search rate limiting
    private var activeSearchOperation: Task<Void, Never>?
    private var isHandlingSearchQueue = false
    private var searchQueryQueue: [String] = []
    private var searchStartTime: Date?
    private var searchRequestCount = 0
    
    // Use a property to track the work item
    private var radiusSearchWorkItem: DispatchWorkItem?
    
    // Search text work item
    private var searchTextWorkItem: DispatchWorkItem?
    
    // MARK: - Initialization
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        
        // Process direction requests at a controlled rate
        timerCancellable = Timer.publish(every: 2.0, on: .main, in: .common) // Reduced frequency
            .autoconnect()
            .sink { [weak self] _ in
                self?.processNextDirectionRequest()
            }
    }
    
    deinit {
        directionRequestThrottleTimer?.invalidate()
        activeSearchOperation?.cancel()
    }
    
    // MARK: - Public Methods
    
    // Add a computed property to safely access user location
    var userLocation: CLLocation? {
        return locationManager.userLocation
    }
    
    // For backward compatibility
    var location1: Location? {
        return locations.count > 0 ? locations[0] : nil
    }
    
    var location2: Location? {
        return locations.count > 1 ? locations[1] : nil
    }
    
    // Check if we can add more locations
    var canAddLocation: Bool {
        return locations.count < maxLocations
    }
    
    // Add a location to the locations array
    func addLocation(_ location: Location) {
        guard locations.count < maxLocations else { return }
        self.locations.append(location)
        self.errorMessage = nil // Clear errors when setting location
        calculateMidpointIfPossible()
    }
    
    // Set a location at a specific index
    func setLocation(at index: Int, to location: Location) {
        guard index >= 0 else { return }
        
        if index < locations.count {
            // Replace existing location
            locations[index] = location
        } else if index == locations.count && index < maxLocations {
            // Add new location
            locations.append(location)
        }
        
        self.errorMessage = nil // Clear errors when setting location
        calculateMidpointIfPossible()
    }
    
    // Remove a location at a specific index
    func removeLocation(at index: Int) {
        guard index >= 0 && index < locations.count else { return }
        locations.remove(at: index)
        calculateMidpointIfPossible()
    }
    
    // Clear all locations
    func clearAllLocations() {
        self.locations.removeAll()
        self.midpoint = nil
        self.places = []
        self.filteredPlaces = []
        self.allPlaces = []
        self.selectedCategory = nil
        self.searchText = ""
        self.errorMessage = nil
    }
    
    // Legacy functions for backward compatibility
    func setLocation1(_ location: Location) {
        if locations.isEmpty {
            locations.append(location)
        } else {
            locations[0] = location
        }
        self.errorMessage = nil // Clear errors when setting location
        calculateMidpointIfPossible()
    }
    
    func setLocation2(_ location: Location) {
        if locations.count < 1 {
            locations.append(Location.currentLocation(with: CLLocationCoordinate2D(latitude: 0, longitude: 0)))
            locations.append(location)
        } else if locations.count < 2 {
            locations.append(location)
        } else {
            locations[1] = location
        }
        self.errorMessage = nil // Clear errors when setting location
        calculateMidpointIfPossible()
    }
    
    func clearLocation1() {
        if !locations.isEmpty {
            locations.remove(at: 0)
        }
        if locations.isEmpty {
            self.midpoint = nil
            self.places = []
            self.filteredPlaces = []
            self.allPlaces = []
            self.selectedCategory = nil
            self.searchText = ""
        }
        self.errorMessage = nil
        calculateMidpointIfPossible()
    }
    
    func clearLocation2() {
        if locations.count > 1 {
            locations.remove(at: 1)
            calculateMidpointIfPossible()
        }
        self.errorMessage = nil
    }
    
    func useCurrentLocationFor1() {
        guard let userLocation = locationManager.userLocation else { 
            DispatchQueue.main.async {
                self.errorMessage = "Unable to access your current location"
            }
            return 
        }
        
        let currentLocation = Location.currentLocation(with: userLocation.coordinate)
        
        if locations.isEmpty {
            locations.append(currentLocation)
        } else {
            locations[0] = currentLocation
        }
        
        self.errorMessage = nil // Clear errors when setting location
        calculateMidpointIfPossible()
    }
    
    func useCurrentLocationFor2() {
        guard let userLocation = locationManager.userLocation else { 
            DispatchQueue.main.async {
                self.errorMessage = "Unable to access your current location"
            }
            return 
        }
        
        let currentLocation = Location.currentLocation(with: userLocation.coordinate)
        
        if locations.count < 1 {
            locations.append(Location.currentLocation(with: CLLocationCoordinate2D(latitude: 0, longitude: 0)))
            locations.append(currentLocation)
        } else if locations.count < 2 {
            locations.append(currentLocation)
        } else {
            locations[1] = currentLocation
        }
        
        self.errorMessage = nil // Clear errors when setting location
        calculateMidpointIfPossible()
    }
    
    // Add a method to use current location at an index
    func useCurrentLocation(at index: Int) {
        guard let userLocation = locationManager.userLocation else { 
            DispatchQueue.main.async {
                self.errorMessage = "Unable to access your current location"
            }
            return 
        }
        
        let currentLocation = Location.currentLocation(with: userLocation.coordinate)
        
        if index < locations.count {
            locations[index] = currentLocation
        } else if index == locations.count && index < maxLocations {
            locations.append(currentLocation)
        }
        
        self.errorMessage = nil
        calculateMidpointIfPossible()
    }
    
    func filterByCategory(_ category: PlaceCategory?) {
        // Update immediately on main thread
        if category == self.selectedCategory {
            self.selectedCategory = nil
        } else {
            self.selectedCategory = category
        }
        
        // Clear error message
        self.errorMessage = nil
        
        // Filter synchronously for instant response
        self.filterPlacesWithCurrentSettings()
        
        // If no results, start async search expansion
        if self.filteredPlaces.isEmpty {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.expandSearchForCategory(category)
            }
        }
    }
    
    // Add this new method for category expansion
    private func expandSearchForCategory(_ category: PlaceCategory?) {
        guard let category = category else { return }
        
        let expansionQueries: [String]
        switch category {
        case .bar:
            expansionQueries = ["pub", "nightclub", "lounge", "wine bar", "brewery"]
        case .restaurant:
            expansionQueries = ["bistro", "eatery", "steakhouse", "brasserie"]
        case .cafe:
            expansionQueries = ["coffee shop", "espresso bar", "patisserie"]
        case .park:
            expansionQueries = ["green space", "playground", "recreation area"]
        default:
            return
        }
        
        // Add to search queue and trigger search
        DispatchQueue.main.async { [weak self] in
            self?.searchQueryQueue.insert(contentsOf: expansionQueries, at: 0)
            self?.searchPlacesAroundMidpoint()
        }
    }
    
    // Modified method to filter places based on search text and category
    func filterPlacesWithCurrentSettings() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create local copies to prevent concurrent access issues
            let searchText = self.searchText.lowercased()
            let selectedCategory = self.selectedCategory
            let allPlaces = self.allPlaces
            
            let filtered: [Place]
            
            if searchText.isEmpty {
                // If no search text, just apply category filter
                if let selectedCategory = selectedCategory {
                    filtered = allPlaces.filter { $0.category == selectedCategory }
                } else {
                    filtered = allPlaces
                }
            } else {
                // If search text exists, apply both search and category filter
                filtered = allPlaces.filter { place in
                    // Apply category filter if needed
                    let passesCategory = selectedCategory == nil || place.category == selectedCategory
                    
                    // If it doesn't pass category filter, return early
                    guard passesCategory else { return false }
                    
                    // Apply search text filter
                    let placeName = place.name.lowercased()
                    let categoryName = place.category.rawValue.lowercased()
                    let thoroughfare = place.mapItem.placemark.thoroughfare?.lowercased() ?? ""
                    let locality = place.mapItem.placemark.locality?.lowercased() ?? ""
                    
                    return placeName.contains(searchText) || 
                           categoryName.contains(searchText) || 
                           thoroughfare.contains(searchText) ||
                           locality.contains(searchText)
                }
            }
            
            // Update on main thread
            DispatchQueue.main.async {
                // Even if filtered results are empty, we should still stay in the results panel
                // if we're actively searching - never switch back to search panel during active search
                self.filteredPlaces = filtered
                
                // Log the results state to help with debugging
                print("Search: \"\(searchText)\", Category: \(selectedCategory?.rawValue ?? "all"), Results: \(filtered.count)")
            }
        }
    }
    
    // Add contextual matching helper
    private func contextualMatch(term: String, place: Place) -> Bool {
        let foodTerms: Set = ["food", "eat", "dining", "meal", "lunch", "dinner"]
        let drinkTerms: Set = ["drink", "coffee", "tea", "beverage"]
        
        switch place.category {
        case .restaurant, .cafe:
            return foodTerms.contains(term) || drinkTerms.contains(term)
        case .bar:
            return drinkTerms.contains(term) || term == "bar"
        case .park:
            return term == "park" || term == "nature"
        default:
            return false
        }
    }
    
    // MARK: - Search Methods
    
    func searchPlacesAroundMidpoint() {
        guard let midpoint = midpoint else {
            return // Silent fail if no midpoint
        }
        
        // Keep existing results while searching
        DispatchQueue.main.async { 
            self.isSearching = true
            // Don't clear previous results during new search
            self.errorMessage = nil
        }
        
        // Cancel any ongoing searches
        activeSearchOperation?.cancel()
        searchStartTime = nil
        searchRequestCount = 0
        
        // Clear the search queue
        searchQueryQueue.removeAll()
        
        // Start fresh
        DispatchQueue.main.async {
            self.places = []
            self.filteredPlaces = []
            self.allPlaces = []
            self.selectedCategory = nil // Reset category when starting a new search
            self.searchText = "" // Reset search text when starting a new search
        }
        
        // Clear any pending direction requests
        directionRequestsQueue.removeAll()
        
        // Expanded search queries
        searchQueryQueue = [
            "restaurant", "cafe", "shopping", "grocery",
            "entertainment", "bar", "park", "bakery", "gym"
        ]
        
        // Start the sequential search process with improved performance
        processSearchQueue(midpoint: midpoint, region: MKCoordinateRegion(
            center: midpoint,
            latitudinalMeters: searchRadius * 2000, 
            longitudinalMeters: searchRadius * 2000
        ), completion: { [weak self] places in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Merge new results with existing ones
                let newPlaces = places.filter { place in
                    place.distanceFromMidpoint <= (self.searchRadius * 1000)
                }
                
                self.allPlaces = (self.allPlaces + newPlaces)
                    .reduce(into: [Place]()) { result, place in
                        if !result.contains(where: { $0.id == place.id }) {
                            result.append(place)
                        }
                    }
                    .sorted { $0.distanceFromMidpoint < $1.distanceFromMidpoint }
                
                self.filterPlacesWithCurrentSettings()
                self.isSearching = false
                
                // Queue directions after search completes
                self.queueDirectionRequestsForAllLocations()
            }
        })
    }
    
    // This is a faster search function that processes queries with better performance
    private func processSearchQueue(midpoint: CLLocationCoordinate2D, region: MKCoordinateRegion, completion: @escaping ([Place]) -> Void) {
        // Cancel any previous operation
        activeSearchOperation?.cancel()
        
        var foundPlaces: [Place] = []
        
        // Create a new async task to handle the search queue
        activeSearchOperation = Task { [weak self] in
            guard let self = self else { return }
            
            // Initialize search start time if needed
            if searchStartTime == nil {
                searchStartTime = Date()
                searchRequestCount = 0
            }
            
            // Parallel search to improve performance but stay within rate limits
            var currentQueries = [String]()
            
            // Process queries in batches of 2 for parallel execution while staying under limits
            while !Task.isCancelled && !searchQueryQueue.isEmpty {
                // Check if we need to wait due to rate limiting
                if searchRequestCount >= 30 { // Lower threshold to avoid hitting limits
                    let elapsedTime = Date().timeIntervalSince(searchStartTime ?? Date())
                    if elapsedTime < 60 {
                        let waitTime = 60 - elapsedTime + 0.5 // Shorter buffer
                        print("Rate limit approaching, waiting \(waitTime) seconds")
                        
                        do {
                            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                            searchStartTime = Date()
                            searchRequestCount = 0
                        } catch {
                            break // Task was cancelled during sleep
                        }
                    } else {
                        // Reset counter after 60 seconds
                        searchStartTime = Date()
                        searchRequestCount = 0
                    }
                }
                
                guard !Task.isCancelled else { break }
                
                // Take up to 2 queries at a time for parallel processing
                let batchSize = min(2, searchQueryQueue.count)
                currentQueries = Array(searchQueryQueue.prefix(batchSize))
                searchQueryQueue.removeFirst(batchSize)
                
                // Search in parallel for faster results
                await withTaskGroup(of: [Place].self) { group in
                    for query in currentQueries {
                        group.addTask {
                            do {
                                // Increment request counter
                                self.searchRequestCount += 1
                                
                                // Create a search request
                                let request = MKLocalSearch.Request()
                                request.naturalLanguageQuery = query
                                request.region = region
                                
                                let search = MKLocalSearch(request: request)
                                
                                // Fix for the generic parameter inference error by explicitly specifying the type
                                let response: MKLocalSearch.Response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MKLocalSearch.Response, Error>) in
                                    search.start { response, error in
                                        if let error = error {
                                            continuation.resume(throwing: error)
                                        } else if let response = response {
                                            continuation.resume(returning: response)
                                        } else {
                                            continuation.resume(throwing: NSError(domain: "SearchError", code: 0, userInfo: nil))
                                        }
                                    }
                                }
                                
                                // Process the results - limit to 5 per query to reduce direction requests
                                return response.mapItems.prefix(5).map { item -> Place in
                                    let category = self.determineCategory(for: item)
                                    let distance = self.locationManager.calculateDistance(
                                        location1: midpoint, 
                                        location2: item.placemark.coordinate
                                    )
                                    
                                    return Place(
                                        id: UUID().uuidString,
                                        name: item.name ?? "Unknown Place",
                                        coordinate: item.placemark.coordinate,
                                        category: category,
                                        distanceFromMidpoint: distance,
                                        mapItem: item
                                    )
                                }
                            } catch {
                                print("Search error: \(error.localizedDescription)")
                                
                                if let mkError = error as? MKError, mkError.code == .loadingThrottled {
                                    // We hit a rate limit, put query back if there's space
                                    if !self.searchQueryQueue.contains(query) && self.searchQueryQueue.count < 10 {
                                        self.searchQueryQueue.append(query)
                                    }
                                }
                                return []
                            }
                        }
                    }
                    
                    // Collect results
                    for await places in group {
                        foundPlaces.append(contentsOf: places)
                    }
                }
                
                // Small delay between batches to avoid rate limits - much shorter
                if !searchQueryQueue.isEmpty {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
            }
            
            // Only complete if the task wasn't cancelled
            if !Task.isCancelled {
                completion(foundPlaces)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateMidpointIfPossible() {
        // If we have 0 locations, no midpoint
        if locations.isEmpty {
            self.midpoint = nil
            return
        }
        
        // If we have only 1 location, use it as the center point
        if locations.count == 1 {
            self.midpoint = locations[0].coordinate
            // Set a default search radius for single location
            self.maxSearchRadius = 5.0
            
            // After calculating midpoint, initiate search
            DispatchQueue.main.async {
                self.searchPlacesAroundMidpoint()
            }
            return
        }
        
        // For 2+ locations, calculate proper midpoint
        // Extract all coordinates
        let coordinates = locations.map { $0.coordinate }
        
        // Calculate the midpoint of all locations
        self.midpoint = locationManager.calculateMidpointOfMultipleLocations(coordinates: coordinates)
        
        // Calculate max search radius based on maximum distance between any two locations
        var maxDistance: CLLocationDistance = 0
        
        for i in 0..<coordinates.count {
            for j in (i+1)..<coordinates.count {
                let distance = locationManager.calculateDistance(
                    location1: coordinates[i],
                    location2: coordinates[j]
                )
                maxDistance = max(maxDistance, distance)
            }
        }
        
        // Set max radius to half the max distance plus a bit more for flexibility
        self.maxSearchRadius = min(max(maxDistance / 1000 * 0.7, 5.0), 20.0) // Between 5km and 20km
        
        // If current radius is more than max, adjust it
        if self.searchRadius > self.maxSearchRadius {
            self.searchRadius = self.maxSearchRadius
        }
        
        // After calculating midpoint, initiate search
        DispatchQueue.main.async {
            self.searchPlacesAroundMidpoint()
        }
    }
    
    // Updated to handle multiple locations efficiently
    private func queueDirectionRequestsForAllLocations() {
        guard !locations.isEmpty, !allPlaces.isEmpty else { return }
        
        // Only process the top places to reduce API calls
        let topPlaces = allPlaces.prefix(min(10, allPlaces.count))
        
        // For each place, only request directions from each location once
        for place in topPlaces {
            // Cap the number of locations to avoid excessive API calls
            let locationsToProcess = locations.prefix(min(5, locations.count))
            
            for (index, location) in locationsToProcess.enumerated() {
                // Always get driving directions
                let drivingRequest = DirectionRequest(
                    placeId: place.id,
                    from: location.coordinate,
                    to: place.coordinate,
                    transportType: .automobile
                )
                directionRequestsQueue.append(drivingRequest)
                
                // Only get walking directions for the top 5 places
                if topPlaces.prefix(5).contains(where: { $0.id == place.id }) {
                    let walkingRequest = DirectionRequest(
                        placeId: place.id,
                        from: location.coordinate,
                        to: place.coordinate,
                        transportType: .walking
                    )
                    directionRequestsQueue.append(walkingRequest)
                }
            }
        }
        
        // Start processing the queue if not already doing so
        processNextDirectionRequest()
    }
    
    private func determineCategory(for mapItem: MKMapItem) -> PlaceCategory {
        // Get both the raw value and any additional categories from the point of interest
        let categories = mapItem.pointOfInterestCategory?.rawValue ?? ""
        let placeName = mapItem.name?.lowercased() ?? ""
        
        // Food-related categories
        if categories.contains("restaurant") || 
           categories.contains("food") || 
           placeName.contains("restaurant") ||
           placeName.contains("diner") || 
           placeName.contains("grill") {
            return .restaurant
        }
        
        // Cafe and coffee shop categories
        if categories.contains("cafe") || 
           categories.contains("coffee") || 
           placeName.contains("cafe") || 
           placeName.contains("coffee") || 
           placeName.contains("bakery") {
            return .cafe
        }
        
        // Bar and pub categories
        if categories.contains("bar") || 
           categories.contains("pub") || 
           categories.contains("nightlife") || 
           placeName.contains("bar") || 
           placeName.contains("pub") ||
           placeName.contains("tavern") {
            return .bar
        }
        
        // Park and outdoor categories
        if categories.contains("park") || 
           categories.contains("garden") || 
           categories.contains("outdoor") || 
           placeName.contains("park") || 
           placeName.contains("garden") || 
           placeName.contains("trail") {
            return .park
        }
        
        return .other
    }
    
    // Process the next request in the queue - Rate limited
    private func processNextDirectionRequest() {
        guard !isProcessingDirectionRequests, !directionRequestsQueue.isEmpty else {
            return
        }
        
        isProcessingDirectionRequests = true
        let request = directionRequestsQueue.removeFirst()
        
        // Calculate directions
        let directionsRequest = MKDirections.Request()
        directionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: request.from))
        directionsRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: request.to))
        directionsRequest.transportType = request.transportType
        
        let directions = MKDirections(request: directionsRequest)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            
            defer {
                self.isProcessingDirectionRequests = false
                // Delay next request to avoid throttling
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.processNextDirectionRequest()
                }
            }
            
            if let error = error {
                print("Direction calculation error: \(error.localizedDescription)")
                
                // If we hit rate limits, add more delay
                if (error as NSError).domain == "MKErrorDomain" && (error as NSError).code == 3 {
                    // Add extra delay for rate limits and requeue the request
                    directionRequestThrottleTimer?.invalidate()
                    directionRequestThrottleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        // Requeue the request at end of queue (not beginning)
                        self.directionRequestsQueue.append(request)
                        self.processNextDirectionRequest()
                    }
                }
                return
            }
            
            guard let route = response?.routes.first else { return }
            
            DispatchQueue.main.async {
                // Find the place and update its travel time in both arrays
                if let index = self.allPlaces.firstIndex(where: { $0.id == request.placeId }) {
                    var place = self.allPlaces[index]
                    
                    let travelTimeMinutes = Int(route.expectedTravelTime / 60)
                    
                    // Find which location this is from
                    let locationIndex = self.findLocationIndex(for: request.from)
                    
                    // Update travel time using the new method
                    place.updateTravelTime(
                        fromLocationIndex: locationIndex,
                        transportType: request.transportType,
                        minutes: travelTimeMinutes
                    )
                    
                    self.allPlaces[index] = place
                    
                    // Also update in filteredPlaces if it exists there
                    if let filteredIndex = self.filteredPlaces.firstIndex(where: { $0.id == request.placeId }) {
                        self.filteredPlaces[filteredIndex] = place
                    }
                }
            }
        }
    }
    
    // Helper method to find the index of a location based on its coordinate
    private func findLocationIndex(for coordinate: CLLocationCoordinate2D) -> Int {
        for (index, location) in locations.enumerated() {
            if location.coordinate.latitude == coordinate.latitude && 
               location.coordinate.longitude == coordinate.longitude {
                return index
            }
        }
        return 0 // Default to first location if not found
    }
    
    func updateSearchRadius(_ radius: Double) {
        // Constrain the radius to our calculated maximum
        let constrainedRadius = min(radius, maxSearchRadius)
        
        if constrainedRadius == self.searchRadius {
            return // No change, avoid unnecessary search
        }
        
        // Update immediately for smooth slider movement
        self.searchRadius = constrainedRadius
        
        // Only trigger a search if we have a midpoint
        if midpoint != nil {
            // Debounce the actual search to avoid too frequent API calls
            debounceRadiusSearch()
        }
    }
    
    private func debounceRadiusSearch() {
        // Cancel the previous work item if it exists
        radiusSearchWorkItem?.cancel()
        
        // Create a new work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Check if we should update the places
            let currentPlaces = self.places
            
            // Only search if we have no places or need to expand search
            if currentPlaces.isEmpty || self.filteredPlaces.isEmpty {
                self.searchPlacesAroundMidpoint()
            } else {
                // Just filter existing places based on new radius
                DispatchQueue.main.async {
                    self.allPlaces = self.allPlaces.filter { place in
                        place.distanceFromMidpoint <= (self.searchRadius * 1000) // Convert km to meters
                    }.sorted {
                        $0.distanceFromMidpoint < $1.distanceFromMidpoint
                    }
                    
                    if self.allPlaces.isEmpty {
                        // If filtering led to empty results, do a new search
                        self.searchPlacesAroundMidpoint()
                    } else {
                        // Just update filtered places based on current filters
                        self.filterPlacesWithCurrentSettings()
                    }
                }
            }
        }
        
        // Save the reference to the work item
        radiusSearchWorkItem = workItem
        
        // Schedule the work item to be executed after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    // New function for search debouncing that doesn't clear results
    func debounceSearchText(_ text: String) {
        searchTextWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.searchText = text
            self?.filterPlacesWithCurrentSettings()
        }
        
        searchTextWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
}

// Add an extension to LocationManager to calculate midpoint of multiple locations
extension LocationManager {
    func calculateMidpointOfMultipleLocations(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            // Return a default coordinate if no coordinates provided
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        if coordinates.count == 1 {
            return coordinates[0]
        }
        
        var totalLat: Double = 0
        var totalLon: Double = 0
        
        for coordinate in coordinates {
            totalLat += coordinate.latitude
            totalLon += coordinate.longitude
        }
        
        // Average the coordinates
        let avgLat = totalLat / Double(coordinates.count)
        let avgLon = totalLon / Double(coordinates.count)
        
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
}

// Update Place struct to handle multiple locations' travel times
extension Place {
    // This is just a placeholder. The actual implementation would need to track travel times
    // for all locations, not just two.
} 