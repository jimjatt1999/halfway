import Foundation
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        locationError = nil
        locationManager.requestLocation()
    }
    
    func startUpdatingLocation() {
        locationError = nil
        locationManager.startUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            locationError = "Location access is denied. Please enable it in Settings."
        case .notDetermined:
            // Authorization not determined yet
            break
        @unknown default:
            locationError = "Unknown authorization status"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "Location access denied"
            case .network:
                locationError = "Network error. Please check your connection."
            default:
                locationError = "Error getting location: \(error.localizedDescription)"
            }
        } else {
            locationError = "Error getting location: \(error.localizedDescription)"
        }
    }
    
    // Calculate midpoint between two locations
    func calculateMidpoint(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat1 = location1.latitude * .pi / 180
        let lon1 = location1.longitude * .pi / 180
        let lat2 = location2.latitude * .pi / 180
        let lon2 = location2.longitude * .pi / 180
        
        let bx = cos(lat2) * cos(lon2 - lon1)
        let by = cos(lat2) * sin(lon2 - lon1)
        let lat3 = atan2(sin(lat1) + sin(lat2), sqrt((cos(lat1) + bx) * (cos(lat1) + bx) + by * by))
        let lon3 = lon1 + atan2(by, cos(lat1) + bx)
        
        return CLLocationCoordinate2D(
            latitude: lat3 * 180 / .pi,
            longitude: lon3 * 180 / .pi
        )
    }
    
    // Calculate distance between two locations in meters
    func calculateDistance(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
        let loc2 = CLLocation(latitude: location2.latitude, longitude: location2.longitude)
        return loc1.distance(from: loc2)
    }
    
    // Calculate travel times from location to destination
    func calculateTravelTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, completion: @escaping (Int?, Int?) -> Void) {
        let source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        
        var drivingMinutes: Int? = nil
        var walkingMinutes: Int? = nil
        
        // Calculate driving time
        let drivingRequest = MKDirections.Request()
        drivingRequest.source = source
        drivingRequest.destination = destination
        drivingRequest.transportType = .automobile
        
        let drivingDirections = MKDirections(request: drivingRequest)
        drivingDirections.calculate { response, error in
            if let route = response?.routes.first {
                drivingMinutes = Int(route.expectedTravelTime / 60)
            }
            
            // Calculate walking time after driving calculation is done
            let walkingRequest = MKDirections.Request()
            walkingRequest.source = source
            walkingRequest.destination = destination
            walkingRequest.transportType = .walking
            
            let walkingDirections = MKDirections(request: walkingRequest)
            walkingDirections.calculate { response, error in
                if let route = response?.routes.first {
                    walkingMinutes = Int(route.expectedTravelTime / 60)
                }
                
                // Return both results
                DispatchQueue.main.async {
                    completion(drivingMinutes, walkingMinutes)
                }
            }
        }
    }
} 