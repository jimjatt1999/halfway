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
    var isMiniMapInResults: Bool = false // New property to identify mini map in results panel
    
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
         mapType: MKMapType = .standard,
         isMiniMapInResults: Bool = false) {
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
        self.isMiniMapInResults = isMiniMapInResults
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
         mapType: MKMapType = .standard,
         isMiniMapInResults: Bool = false) {
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
        self.isMiniMapInResults = isMiniMapInResults
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = mapType
        
        // Enable nearby points of interest
        mapView.pointOfInterestFilter = .includingAll
        
        // Ensure map interaction is enabled
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        
        // Setup gesture recognizers to track user interaction
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPinch(_:)))
        
        // Add tap gesture recognizer for clearing locations
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.numberOfTapsRequired = 2  // Double tap
        
        // Add long press gesture to copy coordinates
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.8
        
        // Make sure the double tap doesn't interfere with zoom functionality
        for recognizer in mapView.gestureRecognizers ?? [] {
            if let zoomGesture = recognizer as? UITapGestureRecognizer, zoomGesture.numberOfTapsRequired == 2 {
                tapGesture.require(toFail: zoomGesture)
            }
        }
        
        mapView.addGestureRecognizer(panGesture)
        mapView.addGestureRecognizer(pinchGesture)
        mapView.addGestureRecognizer(tapGesture)
        mapView.addGestureRecognizer(longPressGesture)
        
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
        
        // Configure map interaction based on type
        if isMiniMapInResults {
            // Mini map in results panel should be non-interactive
            mapView.isZoomEnabled = false
            mapView.isScrollEnabled = false
            mapView.isRotateEnabled = false
            
            // Always show the midpoint and all locations in mini map
            if let midpoint = midpoint {
                var allPoints: [CLLocationCoordinate2D] = [midpoint]
                
                // Add all locations' coordinates
                if let locs = locations, !locs.isEmpty {
                    allPoints.append(contentsOf: locs.map { $0.coordinate })
                } else if let loc1 = location1?.coordinate {
                    allPoints.append(loc1)
                    if let loc2 = location2?.coordinate {
                        allPoints.append(loc2)
                    }
                }
                
                // Set region to show all points with padding
                let miniMapRegion = regionThatFits(coordinates: allPoints)
                mapView.setRegion(miniMapRegion, animated: false)
            } else {
                // If no midpoint, just show the region
                mapView.setRegion(region, animated: false)
            }
        } else {
            // Main map (homepage and immersive) should be fully interactive
            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = true
            mapView.isRotateEnabled = true
            
            // Check if we should update the region
            // 1. Initial load (userInteracted is false)
            // 2. Expanded state changes
            // 3. Explicit reset request via ResetMapInteraction notification
            let shouldSetRegion = !context.coordinator.userInteracted || 
                                  context.coordinator.lastExpandedState != isExpanded
            
            if shouldSetRegion {
                if isExpanded && context.coordinator.lastExpandedState != isExpanded {
                    // Calculate region to show all points when expanding
                    var allPoints: [CLLocationCoordinate2D] = []
                    if midpoint != nil {
                        allPoints.append(midpoint!)
                    }
                    
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
                    // This handles both initial load and reset from location button
                    // When userInteracted is false, the map will follow the region binding
                    // which gets updated when the location button is pressed
                    mapView.setRegion(region, animated: true)
                }
                
                context.coordinator.lastExpandedState = isExpanded
            }
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
        private var notificationObserver: NSObjectProtocol?
        
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
            
            // Add observer for reset notification - only reset on explicit request
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ResetMapInteraction"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // This is the fix - reset user interaction state
                self?.userInteracted = false
                
                // Also provide haptic feedback to confirm the action
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            
            // Add observer for expanded state changes - but don't reset interaction flag
            // This allows the map to stay where the user left it
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("MapExpandedStateChanged"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // No longer resetting userInteracted here to maintain map position
            }
        }
        
        deinit {
            // Remove observers when coordinator is deallocated
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            
            // Remove all other observers
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func handleMapPan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began || gesture.state == .changed {
                userInteracted = true
            }
        }
        
        @objc func handleMapPinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began || gesture.state == .changed {
                userInteracted = true
            }
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            if gesture.state == .ended {
                DispatchQueue.main.async {
                    // Signal to parent view that user wants to reset locations
                    self.parent.resetLocations = true
                    
                    // No need to show a toast notification for this action
                }
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                let mapView = gesture.view as! MKMapView
                let location = gesture.location(in: mapView)
                let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
                
                // Create a context menu at the long press location
                let alertController = UIAlertController(
                    title: "Location Options",
                    message: "Coordinates: \(coordinate.latitude), \(coordinate.longitude)",
                    preferredStyle: .actionSheet
                )
                
                // Add option to copy coordinates
                alertController.addAction(UIAlertAction(title: "Copy Coordinates", style: .default) { _ in
                    let coordinateString = "\(coordinate.latitude),\(coordinate.longitude)"
                    UIPasteboard.general.string = coordinateString
                    
                    // Show toast notification
                    self.showToast(message: "Coordinates copied!", in: mapView)
                })
                
                // Add option to add as a location
                alertController.addAction(UIAlertAction(title: "Add as Location", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Use reverse geocoding to get the address
                    let geocoder = CLGeocoder()
                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    
                    geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                        if error == nil, let placemark = placemarks?.first {
                            DispatchQueue.main.async {
                                // Create a location from the placemark
                                let name = self.formatPlacemarkAddress(placemark) ?? "Dropped Pin"
                                let mkPlacemark = MKPlacemark(coordinate: coordinate)
                                let location = Location(name: name, placemark: mkPlacemark, coordinate: coordinate)
                                
                                // Notify parent view to add this location (via a notification)
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("AddLocationFromMap"),
                                    object: location
                                )
                                
                                // Show toast notification
                                self.showToast(message: "Location added!", in: mapView)
                            }
                        } else {
                            // If geocoding fails, use coordinates as the name
                            DispatchQueue.main.async {
                                let name = "Dropped Pin"
                                let mkPlacemark = MKPlacemark(coordinate: coordinate)
                                let location = Location(name: name, placemark: mkPlacemark, coordinate: coordinate)
                                
                                // Notify parent view to add this location
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("AddLocationFromMap"),
                                    object: location
                                )
                                
                                // Show toast notification
                                self.showToast(message: "Location added!", in: mapView)
                            }
                        }
                    }
                })
                
                // Add option to open in Apple Maps
                alertController.addAction(UIAlertAction(title: "Open in Maps", style: .default) { _ in
                    let placemark = MKPlacemark(coordinate: coordinate)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = "Selected Location"
                    mapItem.openInMaps()
                })
                
                // Add cancel option
                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                
                // For iPad: Set source for popover
                if let popoverController = alertController.popoverPresentationController {
                    popoverController.sourceView = mapView
                    popoverController.sourceRect = CGRect(x: location.x, y: location.y, width: 0, height: 0)
                }
                
                // Present the context menu
                if let viewController = self.getViewControllerForView(mapView) {
                    viewController.present(alertController, animated: true)
                }
            }
        }
        
        // Helper to get the parent view controller for a view
        private func getViewControllerForView(_ view: UIView) -> UIViewController? {
            var responder: UIResponder? = view
            while responder != nil {
                responder = responder?.next
                if let viewController = responder as? UIViewController {
                    return viewController
                }
            }
            return nil
        }
        
        // Helper to display toast message
        private func showToast(message: String, in view: UIView) {
                        let toastView = UIView()
                        toastView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                        toastView.layer.cornerRadius = 16
                        toastView.clipsToBounds = true
            toastView.alpha = 0
                        
                        let label = UILabel()
            label.text = message
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
                        
            toastView.frame = CGRect(x: 0, y: 0, width: 150, height: 40)
            toastView.center = CGPoint(x: view.center.x, y: view.center.y - 50)
            view.addSubview(toastView)
            
            // Show and hide the toast with animation
                        UIView.animate(withDuration: 0.2, animations: {
                            toastView.alpha = 1
            }) { _ in
                UIView.animate(withDuration: 0.2, delay: 1.5, options: [], animations: {
                                toastView.alpha = 0
                            }) { _ in
                                toastView.removeFromSuperview()
                            }
                        }
                    }
        
        // Helper to format address from a placemark
        private func formatPlacemarkAddress(_ placemark: CLPlacemark) -> String? {
            var addressComponents: [String] = []
            
            if let name = placemark.name, !name.isEmpty {
                addressComponents.append(name)
            }
            
            if let thoroughfare = placemark.thoroughfare {
                addressComponents.append(thoroughfare)
            }
            
            if let locality = placemark.locality {
                addressComponents.append(locality)
            }
            
            return addressComponents.isEmpty ? nil : addressComponents.joined(separator: ", ")
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
                if parent.midpoint != nil {
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
            // User interaction can happen directly through the map view
            // even without our gesture recognizers catching it
            if mapView.isZoomEnabled && mapView.isScrollEnabled {
                userInteracted = true
            }
            
            // Update the parent's region binding
            DispatchQueue.main.async {
                self.parent.region = mapView.region
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