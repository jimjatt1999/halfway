import Foundation
import MapKit

struct Place: Identifiable, Equatable {
    let id: String
    let name: String
    let category: PlaceCategory
    let coordinate: CLLocationCoordinate2D
    let mapItem: MKMapItem
    var distanceFromMidpoint: CLLocationDistance = 0
    
    // Legacy travel time properties for backward compatibility
    var travelTimeFromLocation1: (driving: Int?, walking: Int?) = (nil, nil)
    var travelTimeFromLocation2: (driving: Int?, walking: Int?) = (nil, nil)
    
    // New travel time storage for multiple locations
    var travelTimes: [String: (driving: Int?, walking: Int?)] = [:]
    
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
    
    // Legacy methods for backward compatibility
    mutating func updateDrivingTime(fromLocation1 minutes: Int) {
        self.travelTimeFromLocation1.driving = minutes
        self.travelTimes["0"] = (driving: minutes, walking: self.travelTimes["0"]?.walking)
    }
    
    mutating func updateWalkingTime(fromLocation1 minutes: Int) {
        self.travelTimeFromLocation1.walking = minutes
        self.travelTimes["0"] = (driving: self.travelTimes["0"]?.driving, walking: minutes)
    }
    
    mutating func updateDrivingTime(fromLocation2 minutes: Int) {
        self.travelTimeFromLocation2.driving = minutes
        self.travelTimes["1"] = (driving: minutes, walking: self.travelTimes["1"]?.walking)
    }
    
    mutating func updateWalkingTime(fromLocation2 minutes: Int) {
        self.travelTimeFromLocation2.walking = minutes
        self.travelTimes["1"] = (driving: self.travelTimes["1"]?.driving, walking: minutes)
    }
    
    // New methods for multiple locations
    mutating func updateTravelTime(fromLocationIndex index: Int, transportType: MKDirectionsTransportType, minutes: Int) {
        let indexKey = String(index)
        var currentTimes = travelTimes[indexKey] ?? (driving: nil, walking: nil)
        
        switch transportType {
        case .automobile:
            currentTimes.driving = minutes
        case .walking:
            currentTimes.walking = minutes
        default:
            break
        }
        
        travelTimes[indexKey] = currentTimes
        
        // Update legacy properties for backward compatibility
        if index == 0 {
            travelTimeFromLocation1 = currentTimes
        } else if index == 1 {
            travelTimeFromLocation2 = currentTimes
        }
    }
    
    // Method to get travel time for a specific location
    func getTravelTime(forLocationIndex index: Int) -> (driving: Int?, walking: Int?) {
        let indexKey = String(index)
        return travelTimes[indexKey] ?? (driving: nil, walking: nil)
    }
    
    // Method to get fastest travel time among all locations
    func getFastestTravelTime() -> (driving: Int?, walking: Int?) {
        var fastestDriving: Int? = nil
        var fastestWalking: Int? = nil
        
        for (_, times) in travelTimes {
            if let driving = times.driving {
                if fastestDriving == nil || driving < fastestDriving! {
                    fastestDriving = driving
                }
            }
            
            if let walking = times.walking {
                if fastestWalking == nil || walking < fastestWalking! {
                    fastestWalking = walking
                }
            }
        }
        
        return (driving: fastestDriving, walking: fastestWalking)
    }
    
    // Method to get average travel time among all locations
    func getAverageTravelTime() -> (driving: Int?, walking: Int?) {
        var totalDriving = 0
        var drivingCount = 0
        var totalWalking = 0
        var walkingCount = 0
        
        for (_, times) in travelTimes {
            if let driving = times.driving {
                totalDriving += driving
                drivingCount += 1
            }
            
            if let walking = times.walking {
                totalWalking += walking
                walkingCount += 1
            }
        }
        
        let avgDriving = drivingCount > 0 ? totalDriving / drivingCount : nil
        let avgWalking = walkingCount > 0 ? totalWalking / walkingCount : nil
        
        return (driving: avgDriving, walking: avgWalking)
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