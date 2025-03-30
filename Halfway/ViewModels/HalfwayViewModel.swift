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
    @Published var location1: Location?
    @Published var location2: Location?
    @Published var searchRadius: Double = 1.0 // in kilometers
    
    // Result properties
    @Published var midpoint: CLLocationCoordinate2D?
    @Published var places: [Place] = []
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
    
    // MARK: - Initialization
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        
        // Set up timer to process direction requests at a controlled rate
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processNextDirectionRequest()
            }
    }
    
    // MARK: - Public Methods
    
    // Add a computed property to safely access user location
    var userLocation: CLLocation? {
        return locationManager.userLocation
    }
    
    func setLocation1(_ location: Location) {
        self.location1 = location
        calculateMidpointIfPossible()
    }
    
    func setLocation2(_ location: Location) {
        self.location2 = location
        calculateMidpointIfPossible()
    }
    
    func clearLocation1() {
        self.location1 = nil
        self.midpoint = nil
        self.places = []
    }
    
    func clearLocation2() {
        self.location2 = nil
        self.midpoint = nil
        self.places = []
    }
    
    func useCurrentLocationFor1() {
        guard let userLocation = locationManager.userLocation else { 
            self.errorMessage = "Unable to access your current location"
            return 
        }
        self.location1 = Location.currentLocation(with: userLocation.coordinate)
        calculateMidpointIfPossible()
    }
    
    func useCurrentLocationFor2() {
        guard let userLocation = locationManager.userLocation else { 
            self.errorMessage = "Unable to access your current location"
            return 
        }
        self.location2 = Location.currentLocation(with: userLocation.coordinate)
        calculateMidpointIfPossible()
    }
    
    func filterByCategory(_ category: PlaceCategory?) {
        selectedCategory = category
        
        if midpoint != nil {
            searchPlacesAroundMidpoint()
        }
    }
    
    // MARK: - Search Methods
    
    func searchPlacesAroundMidpoint() {
        guard let midpoint = midpoint, let loc1 = location1?.coordinate else { return }
        
        self.isSearching = true
        self.places = []
        self.errorMessage = nil
        
        // Clear any pending direction requests
        directionRequestsQueue.removeAll()
        
        // Hard-coded queries for different categories to handle search issues
        var queries = ["restaurant", "cafe", "bar", "park"]
        
        if let category = selectedCategory {
            switch category {
            case .restaurant:
                queries = ["restaurant", "food"]
            case .cafe:
                queries = ["cafe", "coffee"]
            case .bar:
                queries = ["bar", "pub"]
            case .park:
                queries = ["park", "garden"]
            case .other:
                if !searchText.isEmpty {
                    queries = [searchText]
                }
            }
        } else if !searchText.isEmpty {
            queries = [searchText]
        }
        
        let group = DispatchGroup()
        var allPlaces: [Place] = []
        
        // Limit number of searches to avoid rate limits
        let maxPlacesPerQuery = 5 // Limit results per query
        
        for query in queries {
            group.enter()
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            
            // Set the search region
            let region = MKCoordinateRegion(
                center: midpoint,
                latitudinalMeters: searchRadius * 2000, // Double the radius for better coverage
                longitudinalMeters: searchRadius * 2000
            )
            request.region = region
            
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, error in
                defer { group.leave() }
                
                guard let self = self else { return }
                
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    return
                }
                
                guard let response = response else { return }
                
                let places = response.mapItems.prefix(maxPlacesPerQuery).map { item -> Place in
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
                
                allPlaces.append(contentsOf: places)
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Filter places to make sure they're within the radius
            let filteredPlaces = allPlaces.filter { place in
                place.distanceFromMidpoint <= (self.searchRadius * 1000) // Convert km to meters
            }
            
            // Sort places by distance from midpoint
            self.places = filteredPlaces.sorted {
                $0.distanceFromMidpoint < $1.distanceFromMidpoint
            }
            
            if self.places.isEmpty {
                self.errorMessage = "No places found in the selected area. Try increasing the radius."
            } else {
                // Queue up direction requests for each place
                self.queueDirectionRequests(loc1: loc1)
            }
            
            self.isSearching = false
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateMidpointIfPossible() {
        guard let loc1 = location1?.coordinate, let loc2 = location2?.coordinate else {
            return
        }
        
        self.midpoint = locationManager.calculateMidpoint(location1: loc1, location2: loc2)
        searchPlacesAroundMidpoint()
    }
    
    private func queueDirectionRequests(loc1: CLLocationCoordinate2D) {
        for place in places {
            // Driving directions
            let drivingRequest = DirectionRequest(
                placeId: place.id,
                from: loc1,
                to: place.coordinate,
                transportType: .automobile
            )
            directionRequestsQueue.append(drivingRequest)
            
            // Walking directions
            let walkingRequest = DirectionRequest(
                placeId: place.id,
                from: loc1,
                to: place.coordinate,
                transportType: .walking
            )
            directionRequestsQueue.append(walkingRequest)
        }
    }
    
    private func determineCategory(for mapItem: MKMapItem) -> PlaceCategory {
        let categories = mapItem.pointOfInterestCategory?.rawValue ?? ""
        
        if categories.contains("restaurant") || categories.contains("food") {
            return .restaurant
        } else if categories.contains("cafe") || categories.contains("coffee") {
            return .cafe
        } else if categories.contains("bar") || categories.contains("pub") {
            return .bar
        } else if categories.contains("park") || categories.contains("garden") {
            return .park
        }
        
        return .other
    }
    
    // Process the next request in the queue
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
                self.processNextDirectionRequest()
            }
            
            if let error = error {
                print("Direction calculation error: \(error.localizedDescription)")
                return
            }
            
            guard let route = response?.routes.first else { return }
            
            DispatchQueue.main.async {
                // Find the place and update its travel time
                if let index = self.places.firstIndex(where: { $0.id == request.placeId }) {
                    var place = self.places[index]
                    
                    let travelTimeMinutes = Int(route.expectedTravelTime / 60)
                    
                    switch request.transportType {
                    case .automobile:
                        place.updateDrivingTime(fromLocation1: travelTimeMinutes)
                    case .walking:
                        place.updateWalkingTime(fromLocation1: travelTimeMinutes)
                    default:
                        break
                    }
                    
                    self.places[index] = place
                }
            }
        }
    }
    
    func updateSearchRadius(_ radius: Double) {
        self.searchRadius = radius
        if midpoint != nil {
            searchPlacesAroundMidpoint()
        }
    }
} 