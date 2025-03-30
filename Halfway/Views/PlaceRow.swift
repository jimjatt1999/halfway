import SwiftUI
import MapKit

struct PlaceRow: View {
    let place: Place
    let midpoint: CLLocationCoordinate2D?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(Color(UIColor(hex: place.category.color)))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: place.category.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                    
                    if midpoint != nil {
                        let distance = place.distanceFromMidpoint
                        let formattedDistance = formatDistance(distance)
                        Text("\(formattedDistance) from midpoint")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
            }
            .padding()
            .background(Color.white)
            
            Divider()
                .padding(.leading, 74)
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
} 