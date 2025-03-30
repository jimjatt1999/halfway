import Foundation
import MapKit

struct Place: Identifiable, Equatable {
    let id: String
    let name: String
    let category: PlaceCategory
    let coordinate: CLLocationCoordinate2D
    let mapItem: MKMapItem
    var distanceFromMidpoint: CLLocationDistance = 0
    
    var travelTimeFromLocation1: (driving: Int?, walking: Int?) = (nil, nil)
    var travelTimeFromLocation2: (driving: Int?, walking: Int?) = (nil, nil)
    
    init(mapItem: MKMapItem) {
        self.id = UUID().uuidString
        self.mapItem = mapItem
        self.name = mapItem.name ?? "Unknown Place"
        self.coordinate = mapItem.placemark.coordinate
        
        if let categories = mapItem.pointOfInterestCategory {
            switch categories {
            case .restaurant:
                self.category = .restaurant
            case .cafe:
                self.category = .cafe
            case .nightlife:
                self.category = .bar
            case .park:
                self.category = .park
            default:
                self.category = .other
            }
        } else {
            self.category = .other
        }
    }
    
    // New initializer for creating a Place with specific parameters
    init(id: String, name: String, coordinate: CLLocationCoordinate2D, category: PlaceCategory, distanceFromMidpoint: CLLocationDistance, mapItem: MKMapItem) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.category = category
        self.distanceFromMidpoint = distanceFromMidpoint
        self.mapItem = mapItem
    }
    
    // Method to update driving time from location 1
    mutating func updateDrivingTime(fromLocation1 minutes: Int) {
        self.travelTimeFromLocation1.driving = minutes
    }
    
    // Method to update walking time from location 1
    mutating func updateWalkingTime(fromLocation1 minutes: Int) {
        self.travelTimeFromLocation1.walking = minutes
    }
    
    static func == (lhs: Place, rhs: Place) -> Bool {
        return lhs.id == rhs.id
    }
}

enum PlaceCategory: String, CaseIterable {
    case restaurant = "Restaurant"
    case cafe = "Cafe"
    case bar = "Bar"
    case park = "Park"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .restaurant:
            return "fork.knife"
        case .cafe:
            return "cup.and.saucer"
        case .bar:
            return "wineglass"
        case .park:
            return "leaf"
        case .other:
            return "mappin"
        }
    }
    
    var color: String {
        switch self {
        case .restaurant:
            return "#F4AE61"
        case .cafe:
            return "#D3BA9E"
        case .bar:
            return "#CC76DD"
        case .park:
            return "#64C466"
        case .other:
            return "#AAAAAA"
        }
    }
} 