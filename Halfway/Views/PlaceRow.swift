import SwiftUI
import MapKit

struct PlaceRow: View {
    let place: Place
    let midpoint: CLLocationCoordinate2D?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                // Category icon with color
                ZStack {
                    Circle()
                        .fill(Color(UIColor(hex: place.category.color)))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: place.category.icon)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if midpoint != nil {
                        Text(formatDistance(place.distanceFromMidpoint))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Travel time information
                travelTimeView
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
            )
            .contentShape(Rectangle())
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // Travel time tags
    private var travelTimeView: some View {
        HStack(spacing: 8) {
            // Show driving time
            if let fastestDriving = place.getFastestTravelTime().driving {
                Label("\(fastestDriving) min", systemImage: "car.fill")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(6)
            }
            
            // Show walking time
            if let fastestWalking = place.getFastestTravelTime().walking {
                Label("\(fastestWalking) min", systemImage: "figure.walk")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(6)
            }
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m from midpoint"
        } else {
            return String(format: "%.1f km from midpoint", distance / 1000)
        }
    }
} 