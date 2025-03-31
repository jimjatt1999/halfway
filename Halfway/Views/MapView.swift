import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var location1: Location?
    var location2: Location?
    var locations: [Location]? // Added to support multiple locations
    var midpoint: CLLocationCoordinate2D?
    var places: [Place]
    var searchRadius: Double
    @Binding var selectedPlace: Place?
    var isExpanded: Bool = false
    @Binding var resetLocations: Bool  // New binding to track reset request
    var mapType: MKMapType = .standard // Default map type
    
    // Added to prevent automatic region changes
    @State private var userInteracted = false
    
    // Flag to enable/disable map panning and zooming
    var allowsInteraction: Bool = true
    
    // Default initializer for backward compatibility
    init(region: Binding<MKCoordinateRegion>, 
         location1: Location?, 
         location2: Location?,
         midpoint: CLLocationCoordinate2D?,
         places: [Place],
         searchRadius: Double,
         selectedPlace: Binding<Place?>,
         isExpanded: Bool = false,
         resetLocations: Binding<Bool>,
         mapType: MKMapType = .standard) {
        self._region = region
        self.location1 = location1
        self.location2 = location2
        self.locations = [location1, location2].compactMap { $0 }
        self.midpoint = midpoint
        self.places = places
        self.searchRadius = searchRadius
        self._selectedPlace = selectedPlace
        self.isExpanded = isExpanded
        self._resetLocations = resetLocations
        self.mapType = mapType
    }
    
    // New initializer for direct locations array
    init(region: Binding<MKCoordinateRegion>, 
         locations: [Location],
         midpoint: CLLocationCoordinate2D?,
         places: [Place],
         searchRadius: Double,
         selectedPlace: Binding<Place?>,
         isExpanded: Bool = false,
         resetLocations: Binding<Bool>,
         mapType: MKMapType = .standard) {
        self._region = region
        self.location1 = locations.count > 0 ? locations[0] : nil
        self.location2 = locations.count > 1 ? locations[1] : nil
        self.locations = locations
        self.midpoint = midpoint
        self.places = places
        self.searchRadius = searchRadius
        self._selectedPlace = selectedPlace
        self.isExpanded = isExpanded
        self._resetLocations = resetLocations
        self.mapType = mapType
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = mapType
        
        // Ensure map interaction is enabled
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        
        // Improve map appearance
        mapView.pointOfInterestFilter = .excludingAll // Hide default POIs for cleaner look
        
        // Set up user tracking - start tracking user location immediately
        mapView.userTrackingMode = .follow
        
        // Setup gesture recognizers to track user interaction
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPinch(_:)))
        
        // Add tap gesture recognizer for clearing locations
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.numberOfTapsRequired = 2  // Double tap
        
        // Make sure the double tap doesn't interfere with zoom functionality
        for recognizer in mapView.gestureRecognizers ?? [] {
            if let zoomGesture = recognizer as? UITapGestureRecognizer, zoomGesture.numberOfTapsRequired == 2 {
                tapGesture.require(toFail: zoomGesture)
            }
        }
        
        mapView.addGestureRecognizer(panGesture)
        mapView.addGestureRecognizer(pinchGesture)
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type if changed
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }
        
        // Check if reset is requested
        if resetLocations {
            // Clear all locations
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            mapView.removeOverlays(mapView.overlays)
            DispatchQueue.main.async {
                // Reset the flag after clearing
                self.resetLocations = false
            }
            return
        }
        
        // For mini-map, always maintain the same region as the main map
        if !isExpanded {
            mapView.setRegion(region, animated: false)
            context.coordinator.lastExpandedState = isExpanded
        } 
        // Only set region for the main map if user hasn't interacted or isExpanded has changed
        else if !context.coordinator.userInteracted || context.coordinator.lastExpandedState != isExpanded {
            if isExpanded {
                // Calculate region to show all points when in expanded mode
                var allPoints: [CLLocationCoordinate2D] = []
                if let midpoint = midpoint { allPoints.append(midpoint) }
                
                // Add all locations' coordinates
                if let locs = locations {
                    allPoints.append(contentsOf: locs.map { $0.coordinate })
                } else {
                    // For backward compatibility
                    if let loc1 = location1?.coordinate { allPoints.append(loc1) }
                    if let loc2 = location2?.coordinate { allPoints.append(loc2) }
                }
                
                if !allPoints.isEmpty {
                    let expandedRegion = regionThatFits(coordinates: allPoints)
                    mapView.setRegion(expandedRegion, animated: true)
                } else {
                    mapView.setRegion(region, animated: true)
                }
            } else {
                mapView.setRegion(region, animated: true)
            }
            
            context.coordinator.lastExpandedState = isExpanded
        }
        
        // Only update annotations if needed
        let shouldUpdateAnnotations = context.coordinator.shouldUpdateAnnotations(
            mapView: mapView,
            locations: locations,
            location1: location1,
            location2: location2,
            midpoint: midpoint,
            places: places
        )
        
        if shouldUpdateAnnotations {
            // Clear existing annotations and overlays
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            mapView.removeOverlays(mapView.overlays)
            
            // Determine which locations to display
            let locationsToShow: [Location]
            if let locs = locations, !locs.isEmpty {
                locationsToShow = locs
            } else {
                // For backward compatibility
                locationsToShow = [location1, location2].compactMap { $0 }
            }
            
            // Add annotations for all locations
            for (index, location) in locationsToShow.enumerated() {
                // Create different types based on index
                let type: LocationAnnotation.LocationType
                switch index {
                case 0: type = .location1
                case 1: type = .location2
                default: type = .additionalLocation(index: index)
                }
                
                let annotation = LocationAnnotation(
                    coordinate: location.coordinate,
                    title: "Location \(index + 1)",
                    type: type
                )
                mapView.addAnnotation(annotation)
            }
            
            // Add midpoint and circle overlay
            if let midpoint = midpoint {
                let annotation = LocationAnnotation(coordinate: midpoint, title: "Midpoint", type: .midpoint)
                mapView.addAnnotation(annotation)
                
                // Add circle overlay for search radius with improved appearance
                let circle = MKCircle(center: midpoint, radius: searchRadius * 1000) // Convert km to meters
                mapView.addOverlay(circle)
                
                // Add line overlays to connect all locations to the midpoint
                for location in locationsToShow {
                    let linePoints = [location.coordinate, midpoint]
                    let polyline = MKPolyline(coordinates: linePoints, count: linePoints.count)
                    mapView.addOverlay(polyline)
                }
            }
            
            // Add place annotations
            for place in places {
                let annotation = PlaceAnnotation(place: place)
                mapView.addAnnotation(annotation)
            }
            
            // Save current state
            context.coordinator.saveCurrentState(
                locations: locationsToShow,
                location1: location1,
                location2: location2,
                midpoint: midpoint,
                places: places,
                searchRadius: searchRadius
            )
        }
        
        // Update region binding when map changes (for consistency between main and mini map)
        if context.coordinator.userInteracted {
            DispatchQueue.main.async {
                self.region = mapView.region
            }
        }
    }
    
    private func regionThatFits(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else { return region }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Improved padding around points - make better use of screen space
        let latPadding = (maxLat - minLat) * 1.2  // 20% padding
        let lonPadding = (maxLon - minLon) * 1.2  // 20% padding
        
        // Ensure minimum span size for better visibility
        let latDelta = max(latPadding, 0.02)
        let lonDelta = max(lonPadding, 0.02)
        
        let span = MKCoordinateSpan(
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var userInteracted = false
        var lastExpandedState = false
        
        // Properties to track last state
        private var lastLocations: [Location] = []
        private var lastLocation1: Location?
        private var lastLocation2: Location?
        private var lastMidpoint: CLLocationCoordinate2D?
        private var lastPlaces: [Place] = []
        private var lastSearchRadius: Double = 0
        
        init(_ parent: MapView) {
            self.parent = parent
            super.init()
        }
        
        @objc func handleMapPan(_ gesture: UIPanGestureRecognizer) {
            userInteracted = true
        }
        
        @objc func handleMapPinch(_ gesture: UIPinchGestureRecognizer) {
            userInteracted = true
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            if gesture.state == .ended {
                DispatchQueue.main.async {
                    // Signal to parent view that user wants to reset locations
                    self.parent.resetLocations = true
                    
                    // Show improved toast message
                    if let mapView = gesture.view as? MKMapView {
                        let toastView = UIView()
                        toastView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                        toastView.layer.cornerRadius = 16
                        toastView.clipsToBounds = true
                        
                        let label = UILabel()
                        label.text = "Map cleared!"
                        label.textColor = .white
                        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                        label.textAlignment = .center
                        
                        toastView.addSubview(label)
                        label.translatesAutoresizingMaskIntoConstraints = false
                        NSLayoutConstraint.activate([
                            label.centerXAnchor.constraint(equalTo: toastView.centerXAnchor),
                            label.centerYAnchor.constraint(equalTo: toastView.centerYAnchor),
                            label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 16),
                            label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -16)
                        ])
                        
                        toastView.frame = CGRect(x: 0, y: 0, width: 130, height: 36)
                        toastView.center = CGPoint(x: mapView.center.x, y: mapView.center.y - 50)
                        mapView.addSubview(toastView)
                        
                        // Fade in
                        toastView.alpha = 0
                        UIView.animate(withDuration: 0.2, animations: {
                            toastView.alpha = 1
                        })
                        
                        // Remove toast after delay with animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            UIView.animate(withDuration: 0.3, animations: {
                                toastView.alpha = 0
                            }) { _ in
                                toastView.removeFromSuperview()
                            }
                        }
                    }
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            if let placeAnnotation = annotation as? PlaceAnnotation {
                let identifier = "PlacePin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: placeAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    annotationView?.titleVisibility = .adaptive
                    
                    // Add detail disclosure button with improved styling
                    let button = UIButton(type: .detailDisclosure)
                    button.tintColor = UIColor.systemIndigo
                    annotationView?.rightCalloutAccessoryView = button
                } else {
                    annotationView?.annotation = placeAnnotation
                }
                
                // Enhanced styling based on category
                let category = placeAnnotation.place.category
                annotationView?.markerTintColor = UIColor(named: category.color) ?? .red
                annotationView?.glyphImage = UIImage(systemName: category.icon)
                annotationView?.displayPriority = .defaultLow  // Ensure they don't cluster too aggressively
                
                return annotationView
            }
            
            if let locationAnnotation = annotation as? LocationAnnotation {
                let identifier = "LocationPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: locationAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    annotationView?.displayPriority = .required  // These should always be visible
                } else {
                    annotationView?.annotation = locationAnnotation
                }
                
                // Enhanced styling based on type
                switch locationAnnotation.type {
                case .location1:
                    annotationView?.markerTintColor = UIColor.systemBlue
                    annotationView?.glyphImage = UIImage(systemName: "1.circle.fill")
                    annotationView?.selectedGlyphImage = UIImage(systemName: "1.circle.fill")
                case .location2:
                    annotationView?.markerTintColor = UIColor.systemGreen
                    annotationView?.glyphImage = UIImage(systemName: "2.circle.fill")
                    annotationView?.selectedGlyphImage = UIImage(systemName: "2.circle.fill")
                case .midpoint:
                    annotationView?.markerTintColor = UIColor.systemRed
                    annotationView?.glyphImage = UIImage(systemName: "star.fill")
                    annotationView?.selectedGlyphImage = UIImage(systemName: "star.fill")
                case .additionalLocation(let index):
                    // Use different colors for additional locations
                    let colors: [UIColor] = [.systemPurple, .systemOrange, .systemPink]
                    let colorIndex = (index - 2) % colors.count  // -2 because indices 0,1 are for location1/2
                    
                    annotationView?.markerTintColor = colors[colorIndex]
                    annotationView?.glyphImage = UIImage(systemName: "\(index + 1).circle.fill")
                    annotationView?.selectedGlyphImage = UIImage(systemName: "\(index + 1).circle.fill")
                }
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
                renderer.lineWidth = 1.5
                return renderer
            }
            
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // Determine which location this line connects to
                if let midpoint = parent.midpoint {
                    let startPoint = polyline.points()[0]
                    let startCoord = CLLocationCoordinate2D(
                        latitude: startPoint.coordinate.latitude,
                        longitude: startPoint.coordinate.longitude
                    )
                    
                    // Get all location coordinates for comparison
                    var locationCoords: [(index: Int, coord: CLLocationCoordinate2D)] = []
                    
                    if let locations = parent.locations {
                        for (index, location) in locations.enumerated() {
                            locationCoords.append((index, location.coordinate))
                        }
                    } else {
                        if let loc1 = parent.location1?.coordinate {
                            locationCoords.append((0, loc1))
                        }
                        if let loc2 = parent.location2?.coordinate {
                            locationCoords.append((1, loc2))
                        }
                    }
                    
                    // Find which location is closest to the start point
                    var closestIndex = 0
                    var minDistance = Double.greatestFiniteMagnitude
                    
                    for (index, coord) in locationCoords {
                        let distance = distanceBetween(startCoord, coord)
                        if distance < minDistance {
                            minDistance = distance
                            closestIndex = index
                        }
                    }
                    
                    // Set color based on location index
                    let colors: [UIColor] = [
                        .systemBlue,    // Location 1
                        .systemGreen,   // Location 2
                        .systemPurple,  // Location 3
                        .systemOrange,  // Location 4
                        .systemPink     // Location 5
                    ]
                    
                    let colorIndex = min(closestIndex, colors.count - 1)
                    renderer.strokeColor = colors[colorIndex].withAlphaComponent(0.7)
                } else {
                    // Default color if we can't determine
                    renderer.strokeColor = UIColor.systemGray.withAlphaComponent(0.7)
                }
                
                // Apply dashed pattern for visual interest
                renderer.lineDashPattern = [4, 4]
                renderer.lineWidth = 2
                
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> CLLocationDistance {
            let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
            return loc1.distance(from: loc2)
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let placeAnnotation = view.annotation as? PlaceAnnotation {
                // Update the selected place binding immediately
                DispatchQueue.main.async {
                    self.parent.selectedPlace = placeAnnotation.place
                }
                
                // Add subtle animation to highlight selected place
                UIView.animate(withDuration: 0.2, animations: {
                    view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                })
            }
        }
        
        // Add this function to properly handle callout accessory taps
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let placeAnnotation = view.annotation as? PlaceAnnotation {
                // Update the selected place binding immediately
                DispatchQueue.main.async {
                    self.parent.selectedPlace = placeAnnotation.place
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            // Reset animation when deselected
            UIView.animate(withDuration: 0.2, animations: {
                view.transform = CGAffineTransform.identity
            })
        }
        
        // Add this method to update the binding when user moves the map
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if userInteracted {
                DispatchQueue.main.async {
                    self.parent.region = mapView.region
                }
            }
        }
        
        func shouldUpdateAnnotations(
            mapView: MKMapView,
            locations: [Location]?,
            location1: Location?,
            location2: Location?,
            midpoint: CLLocationCoordinate2D?,
            places: [Place]
        ) -> Bool {
            // Check if locations array has changed (added or removed locations)
            if let locs = locations {
                if locs.count != lastLocations.count {
                    return true
                }
                
                // Check if any locations have changed
                for (index, location) in locs.enumerated() {
                    if index >= lastLocations.count ||
                       location.coordinate.latitude != lastLocations[index].coordinate.latitude ||
                       location.coordinate.longitude != lastLocations[index].coordinate.longitude {
                        return true
                    }
                }
            }
            
            // Check if legacy locations or midpoint have changed
            if (lastLocation1?.coordinate.latitude != location1?.coordinate.latitude ||
                lastLocation1?.coordinate.longitude != location1?.coordinate.longitude ||
                lastLocation2?.coordinate.latitude != location2?.coordinate.latitude ||
                lastLocation2?.coordinate.longitude != location2?.coordinate.longitude ||
                lastMidpoint?.latitude != midpoint?.latitude ||
                lastMidpoint?.longitude != midpoint?.longitude ||
                lastSearchRadius != parent.searchRadius ||
                lastPlaces.count != places.count) {
                return true
            }
            
            // If nothing significant has changed, don't update annotations
            return false
        }
        
        func saveCurrentState(
            locations: [Location],
            location1: Location?,
            location2: Location?,
            midpoint: CLLocationCoordinate2D?,
            places: [Place],
            searchRadius: Double
        ) {
            lastLocations = locations
            lastLocation1 = location1
            lastLocation2 = location2
            lastMidpoint = midpoint
            lastPlaces = places
            lastSearchRadius = searchRadius
        }
    }
}

class PlaceAnnotation: NSObject, MKAnnotation {
    let place: Place
    
    var coordinate: CLLocationCoordinate2D {
        return place.coordinate
    }
    
    var title: String? {
        return place.name
    }
    
    var subtitle: String? {
        return place.category.rawValue
    }
    
    init(place: Place) {
        self.place = place
        super.init()
    }
}

class LocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let type: LocationType
    
    var subtitle: String? {
        return nil
    }
    
    init(coordinate: CLLocationCoordinate2D, title: String?, type: LocationType) {
        self.coordinate = coordinate
        self.title = title
        self.type = type
        super.init()
    }
    
    enum LocationType {
        case location1
        case location2
        case midpoint
        case additionalLocation(index: Int)
    }
} 