import Foundation
import CoreLocation
import MapKit

// Make Location conform to NSSecureCoding for persistent storage
class Location: NSObject, Identifiable, NSCoding, NSSecureCoding {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let placemark: MKPlacemark
    let isUserLocation: Bool
    
    // Required for NSSecureCoding
    static var supportsSecureCoding: Bool {
        return true
    }
    
    init(name: String, coordinate: CLLocationCoordinate2D, isUserLocation: Bool = false) {
        self.name = name
        self.coordinate = coordinate
        self.isUserLocation = isUserLocation
        self.placemark = MKPlacemark(coordinate: coordinate)
        super.init()
    }
    
    init(name: String, placemark: MKPlacemark, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.coordinate = coordinate
        self.placemark = placemark
        self.isUserLocation = false
        super.init()
    }
    
    // NSCoding implementation for persistence
    required init?(coder: NSCoder) {
        guard let name = coder.decodeObject(of: NSString.self, forKey: "name") as String? else {
            return nil
        }
        
        self.name = name
        let latitude = coder.decodeDouble(forKey: "latitude")
        let longitude = coder.decodeDouble(forKey: "longitude")
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.isUserLocation = coder.decodeBool(forKey: "isUserLocation")
        
        // Recreate placemark from coordinate
        self.placemark = MKPlacemark(coordinate: self.coordinate)
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name as NSString, forKey: "name")
        coder.encode(coordinate.latitude, forKey: "latitude")
        coder.encode(coordinate.longitude, forKey: "longitude")
        coder.encode(isUserLocation, forKey: "isUserLocation")
    }
    
    // Override isEqual from NSObject
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Location else { return false }
        return self.name == other.name && 
               self.coordinate.latitude == other.coordinate.latitude && 
               self.coordinate.longitude == other.coordinate.longitude
    }
    
    // Override hash from NSObject
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        return hasher.finalize()
    }
    
    // Helper for creating a current location
    static func currentLocation(with coordinate: CLLocationCoordinate2D) -> Location {
        return Location(name: "Current Location", coordinate: coordinate, isUserLocation: true)
    }
}

// Add extension to make CLLocationCoordinate2D conform to Equatable
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
} 