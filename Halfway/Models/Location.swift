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
    
    // Added for improved search results ranking
    var relevanceScore: Int = 0
    var subtitle: String? = nil
    var phoneNumber: String? = nil
    var website: URL? = nil
    
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
    
    init(name: String, placemark: MKPlacemark, coordinate: CLLocationCoordinate2D, relevanceScore: Int = 0) {
        self.name = name
        self.coordinate = coordinate
        self.placemark = placemark
        self.isUserLocation = false
        self.relevanceScore = relevanceScore
        
        // Generate a helpful subtitle from placemark information
        self.subtitle = Self.generateSubtitle(from: placemark)
        
        super.init()
    }
    
    // Helper to generate a descriptive subtitle from placemark data
    private static func generateSubtitle(from placemark: MKPlacemark) -> String? {
        var components: [String] = []
        
        // Add thoroughfare if available
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        // Add locality (city)
        if let locality = placemark.locality {
            components.append(locality)
        } else if let subLocality = placemark.subLocality {
            components.append(subLocality)
        }
        
        // Add region/state if available
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
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
        
        // Decode optional properties
        self.relevanceScore = coder.containsValue(forKey: "relevanceScore") ? 
            coder.decodeInteger(forKey: "relevanceScore") : 0
        self.subtitle = coder.decodeObject(of: NSString.self, forKey: "subtitle") as String?
        self.phoneNumber = coder.decodeObject(of: NSString.self, forKey: "phoneNumber") as String?
        self.website = coder.decodeObject(of: NSURL.self, forKey: "website") as URL?
        
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name as NSString, forKey: "name")
        coder.encode(coordinate.latitude, forKey: "latitude")
        coder.encode(coordinate.longitude, forKey: "longitude")
        coder.encode(isUserLocation, forKey: "isUserLocation")
        
        // Encode optional properties
        coder.encode(relevanceScore, forKey: "relevanceScore")
        if let subtitle = subtitle {
            coder.encode(subtitle as NSString, forKey: "subtitle")
        }
        if let phoneNumber = phoneNumber {
            coder.encode(phoneNumber as NSString, forKey: "phoneNumber")
        }
        if let website = website {
            coder.encode(website as NSURL, forKey: "website")
        }
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