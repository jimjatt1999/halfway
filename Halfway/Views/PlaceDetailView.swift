import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: Place
    let locations: [Location]
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab = 0
    @State private var shareContent: String = ""
    @State private var shareItems: [Any] = []
    @State private var showShareSheet: Bool = false
    @State private var shareData: ShareData? = nil
    @State private var isMapInteractionInProgress: Bool = false
    @State private var animationState: Bool = false
    @State private var mapType: MKMapType = .standard
    
    // For backwards compatibility
    init(place: Place, location1: Location?, location2: Location?) {
        self.place = place
        self.locations = [location1, location2].compactMap { $0 }
    }
    
    // New initializer supporting multiple locations
    init(place: Place, locations: [Location]) {
        self.place = place
        self.locations = locations
    }
    
    var body: some View {
        ZStack {
            // Background color
            (colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.systemGroupedBackground))
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Drag indicator at top - make it more prominent
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .cornerRadius(2.5)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle().inset(by: -20))
                    .onTapGesture(count: 2) {
                        // Double-tap on indicator to dismiss
                        presentationMode.wrappedValue.dismiss()
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with place info
                        placeInfoHeader
                            .opacity(animationState ? 1 : 0)
                            .offset(y: animationState ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: animationState)
                        
                        // Quick actions
                        quickActionsSection
                            .opacity(animationState ? 1 : 0)
                            .offset(y: animationState ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: animationState)
                        
                        // Map now in the middle
                        mapSection
                            .opacity(animationState ? 1 : 0)
                            .scaleEffect(animationState ? 1 : 0.95)
                            .animation(.easeOut(duration: 0.4).delay(0.3), value: animationState)
                        
                        // Travel times section
                        travelTimesSection
                            .opacity(animationState ? 1 : 0)
                            .offset(y: animationState ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.4), value: animationState)
                        
                        // Details section
                        detailsSection
                            .opacity(animationState ? 1 : 0)
                            .offset(y: animationState ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.5), value: animationState)
                        
                        // Action buttons at bottom
                        actionButtonsSection
                            .opacity(animationState ? 1 : 0)
                            .offset(y: animationState ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.6), value: animationState)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.systemGroupedBackground))
                    .edgesIgnoringSafeArea(.bottom)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -5)
                    .mask(Rectangle().padding(.top, -20))
            )
        }
        .navigationBarHidden(true)
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    // Only track vertical downward drags from the top area
                    if value.startLocation.y < 100 && value.translation.height > 0 {
                        isMapInteractionInProgress = false
                    }
                }
                .onEnded { value in
                    // Only dismiss if it's a downward drag from the top area 
                    // and not interacting with the map
                    if value.startLocation.y < 100 && 
                       (value.translation.height > 80 || 
                        value.predictedEndTranslation.height > 150) && 
                       !isMapInteractionInProgress {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .sheet(item: $shareData, onDismiss: {
            shareData = nil
        }) { data in
            ShareSheet(activityItems: data.activityItems)
        }
        .onAppear {
            // Trigger animations after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    animationState = true
                }
            }
        }
    }
    
    // MARK: - UI Sections
    
    private var placeInfoHeader: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                // Category icon with color
                ZStack {
                    Circle()
                        .fill(Color(UIColor(hex: place.category.color)))
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                    
                    Image(systemName: place.category.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    // Subtitle (category or address)
                    if let subtitleText = place.mapItem.placemark.thoroughfare {
                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(place.category.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatDistance(place.distanceFromMidpoint) + " from midpoint")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding(.leading, 8)
                
                Spacer()
                
                // Close button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(UIColor.tertiarySystemBackground)))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
            }
            
            // Directions button - prominent action
            Button(action: {
                openInMaps()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .imageScale(.small)
                    Text("Take Me There")
                        .fontWeight(.medium)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor(hex: place.category.color)))
                )
                .foregroundColor(.white)
                .shadow(color: Color(UIColor(hex: place.category.color)).opacity(0.3), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.5) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var mapSection: some View {
        VStack(spacing: 12) {
            // Title row with map type selector
            HStack {
                Text("Location")
                    .font(.headline)
                
                Spacer()
                
                // Map type menu
                Menu {
                    Button(action: { mapType = .standard }) {
                        Label("Standard Map", systemImage: "map")
                    }
                    Button(action: { mapType = .hybrid }) {
                        Label("Satellite View", systemImage: "globe")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Map Type")
                            .font(.footnote)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 8)
            
            // Map with place and locations
            ZStack(alignment: .topTrailing) {
                PlaceMapView(place: place, locations: locations, isInteractingWithMap: $isMapInteractionInProgress, mapType: $mapType)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            
            // Address display
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                
                Text(formatAddress())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    openInMaps()
                }) {
                    Text("Open in Maps")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.5) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            // Section title
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Actions row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    // Common action buttons
                    Group {
                        // Only show Call button if phone number is available
                        if place.mapItem.phoneNumber != nil {
                            ActionButton(title: "Call", icon: "phone.fill", action: makeCall)
                        }
                        
                        // Only show Website button if URL is available
                        if place.mapItem.url != nil {
                            ActionButton(title: "Website", icon: "safari.fill", action: openWebsite)
                        }
                        
                        // Only show Menu button for restaurants, cafes and bars
                        if place.category == .restaurant || place.category == .cafe || place.category == .bar {
                            ActionButton(title: "Menu", icon: "doc.text.fill", action: openMenu)
                        }
                        
                        // Share button
                        ActionButton(title: "Share", icon: "square.and.arrow.up", action: shareLocation)
                        
                        // Location indicators for each location
                        ForEach(0..<min(locations.count, 3), id: \.self) { index in
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(locationColor(for: index))
                                        .frame(width: 56, height: 56)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    
                                    VStack(spacing: 2) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        // Show travel time or distance
                                        let travelTime = place.getTravelTime(forLocationIndex: index)
                                        if let drivingTime = travelTime.driving {
                                            Text("\(drivingTime) min")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        } else {
                                            // Fall back to showing distance
                                            let distance = calculateDistance(from: locations[index].coordinate, to: place.coordinate)
                                            let distanceStr = distance < 1000 ? 
                                                "\(Int(distance))m" : 
                                                String(format: "%.1f km", distance / 1000)
                                            Text(distanceStr)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                
                                Text(locations[index].name.split(separator: ",").first.map(String.init) ?? "Location \(index + 1)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 80)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.5) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var travelTimesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title
            HStack {
                Text("Travel Times")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Travel time cards for each location
            ForEach(0..<locations.count, id: \.self) { index in
                let location = locations[index]
                let travelTime = place.getTravelTime(forLocationIndex: index)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Location name with number
                    HStack(spacing: 10) {
                        // Location number bubble
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(locationColor(for: index)))
                        
                        Text(location.name.split(separator: ",").first.map(String.init) ?? "Location \(index + 1)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    // Travel time indicators
                    HStack(spacing: 12) {
                        // Car travel time
                        HStack(spacing: 6) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            if let drivingTime = travelTime.driving {
                                Text("\(drivingTime) min")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            } else {
                                // Calculate an estimated drive time
                                let distance = calculateDistance(from: location.coordinate, to: place.coordinate)
                                let estimatedDriveTime = max(1, Int(distance / 500)) // Rough estimate: 30km/h
                                Text("~\(estimatedDriveTime) min")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? 
                                      Color(UIColor.tertiarySystemBackground) : 
                                      Color(UIColor.tertiarySystemBackground).opacity(0.5))
                        )
                        
                        // Walking travel time
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            if let walkingTime = travelTime.walking {
                                Text("\(walkingTime) min")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            } else {
                                // Calculate an estimated walk time
                                let distance = calculateDistance(from: location.coordinate, to: place.coordinate)
                                let estimatedWalkTime = max(1, Int(distance / 80)) // Rough estimate: 5km/h
                                Text("~\(estimatedWalkTime) min")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? 
                                      Color(UIColor.tertiarySystemBackground) : 
                                      Color(UIColor.tertiarySystemBackground).opacity(0.5))
                        )
                        
                        // Distance
                        HStack(spacing: 6) {
                            Image(systemName: "ruler")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            let distance = calculateDistance(from: location.coordinate, to: place.coordinate)
                            let distanceStr = distance < 1000 ? 
                                "\(Int(distance))m" : 
                                String(format: "%.1f km", distance / 1000)
                            Text(distanceStr)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? 
                                      Color(UIColor.tertiarySystemBackground) : 
                                      Color(UIColor.tertiarySystemBackground).opacity(0.5))
                        )
                    }
                    .padding(.leading, 8)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? 
                              Color(UIColor.secondarySystemBackground).opacity(0.3) : 
                              Color(UIColor.secondarySystemBackground).opacity(0.3))
                )
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.5) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title
            HStack {
                Text("Details")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Details content
            VStack(spacing: 16) {
                // Contact info group
                if place.mapItem.phoneNumber != nil || place.mapItem.url != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contact")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        
                        Divider()
                            .padding(.vertical, 2)
                        
                        // Website
                        if place.mapItem.url != nil {
                            Button(action: {
                                openWebsite()
                            }) {
                                HStack {
                                    Image(systemName: "safari.fill")
                                        .frame(width: 24)
                                        .foregroundColor(.blue)
                                    
                                    Text("Visit Website")
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 8)
                            }
                        }
                        
                        // Phone
                        if let phoneNumber = place.mapItem.phoneNumber {
                            Divider()
                                .padding(.leading, 32)
                                .opacity(place.mapItem.url != nil ? 1 : 0)
                            
                            Button(action: {
                                makeCall()
                            }) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .frame(width: 24)
                                        .foregroundColor(.green)
                                    
                                    Text(formatPhoneNumber(phoneNumber))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 8)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? 
                                  Color(UIColor.secondarySystemBackground).opacity(0.3) : 
                                  Color(UIColor.secondarySystemBackground).opacity(0.3))
                    )
                    .padding(.horizontal, 8)
                }
                
                // Place info group
                VStack(alignment: .leading, spacing: 4) {
                    Text("About")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    // Category
                    HStack {
                        Image(systemName: place.category.icon)
                            .frame(width: 24)
                            .foregroundColor(Color(UIColor(hex: place.category.color)))
                        
                        Text("Category")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(place.category.rawValue)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    
                    Divider()
                        .padding(.leading, 32)
                    
                    // Distance
                    HStack {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        
                        Text("Distance from midpoint")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatDistance(place.distanceFromMidpoint))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? 
                              Color(UIColor.secondarySystemBackground).opacity(0.3) : 
                              Color(UIColor.secondarySystemBackground).opacity(0.3))
                )
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.5) : Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Different mode options
            Button(action: {
                openInMaps(mode: "MKLaunchOptionsDirectionsModeDriving")
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 20))
                    Text("Drive")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? 
                              Color(UIColor.tertiarySystemBackground) : 
                              Color.white)
                )
                .foregroundColor(.primary)
            }
            
            Button(action: {
                openInMaps(mode: "MKLaunchOptionsDirectionsModeWalking")
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20))
                    Text("Walk")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? 
                              Color(UIColor.tertiarySystemBackground) : 
                              Color.white)
                )
                .foregroundColor(.primary)
            }
            
            Button(action: {
                openInMaps(mode: "MKLaunchOptionsDirectionsModeTransit")
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 20))
                    Text("Transit")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? 
                              Color(UIColor.tertiarySystemBackground) : 
                              Color.white)
                )
                .foregroundColor(.primary)
            }
        }
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            let distanceInKm = distance / 1000
            return String(format: "%.1f km", distanceInKm)
        }
    }
    
    private func formatAddress() -> String {
        let placemark = place.mapItem.placemark
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let subThoroughfare = placemark.subThoroughfare {
            // Insert at beginning if it's a number
            if Int(subThoroughfare) != nil && !components.isEmpty {
                components[0] = "\(subThoroughfare) \(components[0])"
            } else {
                components.append(subThoroughfare)
            }
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        return components.isEmpty ? "View Address" : components.joined(separator: ", ")
    }
    
    private func openInMaps(mode: String = "MKLaunchOptionsDirectionsModeDriving") {
        let options = [
            MKLaunchOptionsDirectionsModeKey: mode
        ]
        
        place.mapItem.openInMaps(launchOptions: options)
    }
    
    private func shareLocation() {
        let baseMessage = "I found this location on Halfway! Let's meet at:\n\n\(place.name)"
        let address = formatAddress() != "View Address" ? "\n\n\(formatAddress())" : ""
        let latitude = place.coordinate.latitude
        let longitude = place.coordinate.longitude
        let mapsLink = "http://maps.apple.com/?ll=\(latitude),\(longitude)"
        let shareText = "\(baseMessage)\(address)\n\n\(mapsLink)"
        
        // Set the shareData asynchronously to ensure the activityItems are ready
        DispatchQueue.main.async {
            self.shareData = ShareData(activityItems: [shareText])
        }
    }
    
    private func makeCall() {
        if let phoneNumber = place.mapItem.phoneNumber {
            let formattedNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
            if let url = URL(string: "tel://\(formattedNumber)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWebsite() {
        if let url = place.mapItem.url, UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
        }
    }
    
    private func openMenu() {
        // Would open menu URL if available
    }
    
    private func showMoreOptions() {
        // Would show additional options
    }
    
    // Helper function to get color based on location index
    func locationColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink]
        return index < colors.count ? colors[index] : .gray
    }
    
    // Helper function to format phone number
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Return the original if it's already formatted nicely
        if phoneNumber.contains(" ") || phoneNumber.contains("-") {
            return phoneNumber
        }
        
        // Basic formatting for US numbers
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        if cleaned.count == 10 {
            let areaCode = cleaned.prefix(3)
            let firstPart = cleaned.dropFirst(3).prefix(3)
            let lastPart = cleaned.dropFirst(6)
            return "(\(areaCode)) \(firstPart)-\(lastPart)"
        }
        
        return phoneNumber
    }
    
    // Helper function to calculate distance between coordinates
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isAvailable: Bool = true
    @Environment(\.colorScheme) var colorScheme
    
    // Determine availability based on place data and button type
    init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        
        // Set initial availability state based on context
        switch icon {
        case "phone":
            // Phone button should be disabled if no phone number
            _isAvailable = State(initialValue: title == "Call" ? UIApplication.shared.canOpenURL(URL(string: "tel://123456789")!) : true)
        case "safari":
            // Website button should be disabled if no website
            _isAvailable = State(initialValue: title == "Website" ? UIApplication.shared.canOpenURL(URL(string: "https://apple.com")!) : true)
        default:
            _isAvailable = State(initialValue: true)
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isAvailable ? .blue : .gray)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(colorScheme == .dark ? 
                                  Color(UIColor.tertiarySystemBackground) : 
                                  Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                    )
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isAvailable ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
            }
        }
        .opacity(isAvailable ? 1.0 : 0.5)
        .disabled(!isAvailable)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .frame(width: 28)
                    .padding(.leading, 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if title == "Hours" || title == "Address" {
                        Text(value)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if title != "Hours" && title != "Category" {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.trailing, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .disabled(title == "Category" || title == "Hours")
    }
}

struct TransitButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? 
                          Color(UIColor.tertiarySystemBackground) : 
                          Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
}

struct PlaceMapView: View {
    let place: Place
    let locations: [Location]
    @Binding var isInteractingWithMap: Bool
    @Binding var mapType: MKMapType
    
    // For backward compatibility without tracking map interaction
    init(place: Place, location1: Location?, location2: Location?) {
        self.place = place
        self.locations = [location1, location2].compactMap { $0 }
        self._isInteractingWithMap = .constant(false)
        self._mapType = .constant(.standard)
    }
    
    // For backward compatibility without tracking map interaction
    init(place: Place, locations: [Location]) {
        self.place = place
        self.locations = locations
        self._isInteractingWithMap = .constant(false)
        self._mapType = .constant(.standard)
    }
    
    // New initializer with interaction tracking
    init(place: Place, locations: [Location], isInteractingWithMap: Binding<Bool>, mapType: Binding<MKMapType>) {
        self.place = place
        self.locations = locations
        self._isInteractingWithMap = isInteractingWithMap
        self._mapType = mapType
    }
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Use our custom map wrapper
            MapViewWrapper(
                region: $region,
                mapType: mapType,
                annotationItems: makeAnnotationItems(),
                annotationContent: { item in
                    if item.isPlace {
                        AnyView(EnhancedPlaceAnnotationView(place: place))
                    } else if item.isMidpoint {
                        AnyView(MidpointAnnotationView())
                    } else {
                        AnyView(EnhancedLocationAnnotationView(index: item.index))
                    }
                },
                isInteractingWithMap: $isInteractingWithMap
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Map type selector
            mapTypeButton
        }
        .onAppear {
            calculateRegion()
        }
    }
    
    private var mapTypeButton: some View {
        Menu {
            Button(action: { mapType = .standard }) {
                Label("Standard Map", systemImage: "map")
            }
            Button(action: { mapType = .hybrid }) {
                Label("Satellite View", systemImage: "globe")
            }
            Button(action: { mapType = .satelliteFlyover }) {
                Label("Satellite Detailed", systemImage: "globe.americas")
            }
        } label: {
            Image(systemName: "map.fill")
                .foregroundColor(.white)
                .padding(10)
                .background(Color.blue.opacity(0.8))
                .clipShape(Circle())
                .shadow(radius: 2)
                .padding(10)
                .overlay(
                    Text("Change Map")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .offset(y: 24)
                )
        }
    }
    
    // Create a unified annotation item list
    private func makeAnnotationItems() -> [AnnotationItem] {
        var items = [AnnotationItem]()
        
        // Add place as annotation
        items.append(AnnotationItem(
            id: "place",
            coordinate: place.coordinate,
            isPlace: true,
            isMidpoint: false,
            index: -1
        ))
        
        // Add locations as annotations
        for (index, location) in locations.enumerated() {
            items.append(AnnotationItem(
                id: "location_\(index)",
                coordinate: location.coordinate,
                isPlace: false,
                isMidpoint: false,
                index: index
            ))
        }
        
        // Calculate and add midpoint if we have at least 2 locations
        if locations.count >= 2 {
            let midCoordinate = calculateMidpoint()
            items.append(AnnotationItem(
                id: "midpoint",
                coordinate: midCoordinate,
                isPlace: false,
                isMidpoint: true,
                index: -1
            ))
        }
        
        return items
    }
    
    private func calculateMidpoint() -> CLLocationCoordinate2D {
        // If we have exactly 2 locations, use direct midpoint
        if locations.count == 2 {
            let lat1 = locations[0].coordinate.latitude
            let lon1 = locations[0].coordinate.longitude
            let lat2 = locations[1].coordinate.latitude
            let lon2 = locations[1].coordinate.longitude
            
            return CLLocationCoordinate2D(
                latitude: (lat1 + lat2) / 2,
                longitude: (lon1 + lon2) / 2
            )
        }
        
        // For more complex cases with 3+ locations, use an average
        let latitudes = locations.map { $0.coordinate.latitude }
        let longitudes = locations.map { $0.coordinate.longitude }
        
        let avgLat = latitudes.reduce(0, +) / Double(latitudes.count)
        let avgLon = longitudes.reduce(0, +) / Double(longitudes.count)
        
        return CLLocationCoordinate2D(
            latitude: avgLat,
            longitude: avgLon
        )
    }
    
    private func calculateRegion() {
        // Start with the place
        var coordinates = [place.coordinate]
        
        // Add all locations
        coordinates.append(contentsOf: locations.map { $0.coordinate })
        
        // Calculate the center and span to include all points
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Add some padding for the static map - slightly wider view
        // so everything is clearly visible without interaction
        let latDelta = max(0.05, (maxLat - minLat) * 1.8)
        let lonDelta = max(0.05, (maxLon - minLon) * 1.8)
        
        // Set the region immediately without animation (static map)
        region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
}

// Custom UIViewRepresentable wrapper to handle map type
struct MapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var mapType: MKMapType
    var annotationItems: [AnnotationItem]
    var annotationContent: (AnnotationItem) -> AnyView
    @Binding var isInteractingWithMap: Bool
    
    // For backward compatibility if you don't want to track map interactions
    init(
        region: Binding<MKCoordinateRegion>,
        mapType: MKMapType,
        annotationItems: [AnnotationItem],
        annotationContent: @escaping (AnnotationItem) -> AnyView
    ) {
        self._region = region
        self.mapType = mapType
        self.annotationItems = annotationItems
        self.annotationContent = annotationContent
        self._isInteractingWithMap = .constant(false)
    }
    
    // With interaction tracking
    init(
        region: Binding<MKCoordinateRegion>,
        mapType: MKMapType,
        annotationItems: [AnnotationItem],
        annotationContent: @escaping (AnnotationItem) -> AnyView,
        isInteractingWithMap: Binding<Bool>
    ) {
        self._region = region
        self.mapType = mapType
        self.annotationItems = annotationItems
        self.annotationContent = annotationContent
        self._isInteractingWithMap = isInteractingWithMap
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.mapType = mapType
        
        // Disable all user interactions
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // We'll still keep the pan gesture recognizer just to track interaction attempts
        // for the parent view's drag gesture, but the map itself won't respond to these
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
        mapView.addGestureRecognizer(panGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Set the region each time but don't animate (static map)
        mapView.setRegion(region, animated: false)
        
        // Update map type
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }
        
        // Update annotations
        mapView.removeAnnotations(mapView.annotations)
        let annotations = annotationItems.map { item -> MKPointAnnotation in
            let annotation = CustomAnnotation()
            annotation.coordinate = item.coordinate
            annotation.itemId = item.id
            return annotation
        }
        mapView.addAnnotations(annotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWrapper
        
        init(_ parent: MapViewWrapper) {
            self.parent = parent
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.region = mapView.region
        }
        
        @objc func handleMapPan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                parent.isInteractingWithMap = true
            case .ended, .cancelled, .failed:
                parent.isInteractingWithMap = false
            default:
                break
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location annotation
            guard !annotation.isKind(of: MKUserLocation.self) else {
                return nil
            }
            
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "customAnnotation")
            annotationView.canShowCallout = false
            
            if let customAnnotation = annotation as? CustomAnnotation,
               let id = customAnnotation.itemId,
               let item = parent.annotationItems.first(where: { $0.id == id }) {
                
                // Create SwiftUI view host
                let view = parent.annotationContent(item)
                let controller = UIHostingController(rootView: view)
                controller.view.backgroundColor = .clear
                
                // Sizing the annotation view properly
                let size = controller.sizeThatFits(in: CGSize(width: 100, height: 100))
                controller.view.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                
                // Add the SwiftUI view as a subview
                annotationView.addSubview(controller.view)
                
                // Center the annotation view on the point
                annotationView.centerOffset = CGPoint(x: 0, y: -size.height / 2)
            }
            
            return annotationView
        }
    }
}

// Custom annotation class to store additional data
class CustomAnnotation: MKPointAnnotation {
    var itemId: String?
}

// Enhanced annotation for a place
struct EnhancedPlaceAnnotationView: View {
    let place: Place
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Outer circle
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            
            // Inner colored circle
            Circle()
                .fill(Color(UIColor(hex: place.category.color)))
                .frame(width: 36, height: 36)
            
            // Icon
            Image(systemName: place.category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
            // Pulsing effect
            Circle()
                .stroke(Color(UIColor(hex: place.category.color)).opacity(0.4), lineWidth: 3)
                .frame(width: isAnimating ? 60 : 44, height: isAnimating ? 60 : 44)
                .opacity(isAnimating ? 0 : 0.8)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// Enhanced annotation for a location
struct EnhancedLocationAnnotationView: View {
    let index: Int
    
    var body: some View {
        ZStack {
            // Outer white circle
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            
            // Inner colored circle
            Circle()
                .fill(locationColor(for: index))
                .frame(width: 28, height: 28)
            
            // Number
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // Helper function to get color based on location index
    private func locationColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink]
        return index < colors.count ? colors[index] : .gray
    }
}

// New annotation for midpoint
struct MidpointAnnotationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 36, height: 36)
            
            // Crosshairs
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
            
            // Pulsing ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                .frame(width: isAnimating ? 48 : 36, height: isAnimating ? 48 : 36)
                .opacity(isAnimating ? 0 : 1)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// Helper model for unified map annotations
struct AnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isPlace: Bool
    let isMidpoint: Bool
    let index: Int
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        
        // Handle completion to dismiss the share sheet
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        
        // Fix iPad presentation style
        if let popover = controller.popoverPresentationController {
            popover.permittedArrowDirections = .any
            popover.sourceView = UIApplication.shared.windows.first?.rootViewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareData: Identifiable {
    let id = UUID()
    let activityItems: [Any]
} 