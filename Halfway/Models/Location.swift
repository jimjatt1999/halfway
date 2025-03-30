import Foundation
import MapKit

struct Location: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let isUserLocation: Bool
    
    init(name: String, coordinate: CLLocationCoordinate2D, isUserLocation: Bool = false) {
        self.name = name
        self.coordinate = coordinate
        self.isUserLocation = isUserLocation
    }
    
    static func currentLocation(with coordinate: CLLocationCoordinate2D) -> Location {
        return Location(name: "Current Location", coordinate: coordinate, isUserLocation: true)
    }
} 