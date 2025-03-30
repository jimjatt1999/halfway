import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: Place
    let location1: Location?
    let location2: Location?
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with place name and category
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: place.category.icon)
                                .foregroundColor(Color(UIColor(hex: place.category.color)))
                            
                            Text(place.category.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        sharePlace()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .padding(10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                
                // Map snippet showing the place
                PlaceMapView(place: place, location1: location1, location2: location2)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                // Travel information section
                VStack(spacing: 16) {
                    // Distance card
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Distance from midpoint")
                                .font(.headline)
                            
                            Text(formatDistance(place.distanceFromMidpoint))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Travel times from location 1
                    if let location1 = location1 {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("From \(location1.name)")
                                    .font(.headline)
                                
                                HStack(spacing: 16) {
                                    if let drivingTime = place.travelTimeFromLocation1.driving {
                                        Label("\(drivingTime) min", systemImage: "car.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let walkingTime = place.travelTimeFromLocation1.walking {
                                        Label("\(walkingTime) min", systemImage: "figure.walk")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    
                    // Travel times from location 2
                    if let location2 = location2 {
                        HStack {
                            Image(systemName: "figure.stand")
                                .font(.title3)
                                .foregroundColor(.green)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("From \(location2.name)")
                                    .font(.headline)
                                
                                HStack(spacing: 16) {
                                    if let drivingTime = place.travelTimeFromLocation2.driving {
                                        Label("\(drivingTime) min", systemImage: "car.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let walkingTime = place.travelTimeFromLocation2.walking {
                                        Label("\(walkingTime) min", systemImage: "figure.walk")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        openInMaps()
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Open in Maps")
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
                    
                    Button(action: {
                        sharePlace()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share This Place")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
        }
        .background(colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            let distanceInKm = distance / 1000
            return String(format: "%.1f km", distanceInKm)
        }
    }
    
    private func openInMaps() {
        let options = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
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
}

struct PlaceMapView: UIViewRepresentable {
    let place: Place
    let location1: Location?
    let location2: Location?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Clear existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add place annotation
        let placeAnnotation = MKPointAnnotation()
        placeAnnotation.coordinate = place.coordinate
        placeAnnotation.title = place.name
        mapView.addAnnotation(placeAnnotation)
        
        // Add route from location1 to place
        if let location1 = location1 {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: location1.coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
            request.transportType = .automobile
            
            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                guard let route = response?.routes.first else { return }
                mapView.addOverlay(route.polyline)
            }
        }
        
        // Set region to show the place
        let region = MKCoordinateRegion(
            center: place.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PlaceMapView
        
        init(_ parent: PlaceMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.blue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
} 