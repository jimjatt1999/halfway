import Foundation
import CoreLocation
import MapKit

struct Location: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let placemark: MKPlacemark
    let isUserLocation: Bool
    
    init(name: String, coordinate: CLLocationCoordinate2D, isUserLocation: Bool = false) {
        self.name = name
        self.coordinate = coordinate
        self.isUserLocation = isUserLocation
        self.placemark = MKPlacemark(coordinate: coordinate)
    }
    
    init(name: String, placemark: MKPlacemark, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.coordinate = coordinate
        self.placemark = placemark
        self.isUserLocation = false
    }
    
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func currentLocation(with coordinate: CLLocationCoordinate2D) -> Location {
        return Location(name: "Current Location", coordinate: coordinate, isUserLocation: true)
    }
} 