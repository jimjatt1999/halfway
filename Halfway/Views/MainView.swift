import SwiftUI
import MapKit
import Combine
import Contacts

struct MainView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel: HalfwayViewModel
    
    @State private var isLocationSearching = false
    @State private var searchFor: Int = 0 // Using an Int to represent the location index
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to SF, will update to user location
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showingErrorAlert = false
    @State private var isExpanded = false
    @State private var resetLocations = false
    @State private var mapType: MKMapType = .standard
    @State private var draggedOffset: CGFloat = 0
    @State private var searchText = ""
    
    // For handling locations added from map
    @State private var locationFromMap: Location? = nil
    
    // Animation states for the title
    @State private var isTitleAnimating = false
    @State private var halfOffset: CGFloat = 0
    @State private var wayOffset: CGFloat = 0
    @State private var titleScale: CGFloat = 1.0
    @State private var titleOpacity: Double = 1.0
    
    // Minimum height for the results panel - increased for better initial visibility
    let minDragHeight: CGFloat = 550 // Changed from 450 to 550 for more screen coverage initially
    // Maximum height for the results panel (will be calculated from screen height)
    var maxDragHeight: CGFloat {
        UIScreen.main.bounds.height * 0.85
    }
    
    @StateObject private var cancellableStore = CancellableStore()
    
    // Add properties for loading animation
    @State private var currentSubtitleIndex = 0
    @State private var subtitleOpacity = 1.0
    @State private var loadingSubtitles = [
        "Finding the perfect middle ground...",
        "Calculating meeting points...",
        "Searching for common ground...",
        "Finding places in between...",
        "Connecting the dots...",
        "Somewhere in the middle..."
    ]
    
    init(viewModel: HalfwayViewModel = HalfwayViewModel(locationManager: LocationManager())) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Map view with blur overlay when results are shown
            MapView(region: $mapRegion, 
                    locations: viewModel.locations,
                    midpoint: viewModel.midpoint,
                    places: viewModel.filteredPlaces,
                    searchRadius: viewModel.searchRadius,
                    selectedPlace: $viewModel.showingPlaceDetail,
                    isExpanded: isExpanded,
                    resetLocations: $resetLocations,
                    mapType: mapType)
                .edgesIgnoringSafeArea(.all)
            
            // Semi-transparent overlay when results are shown (creates subtle depth)
            if !isExpanded && !viewModel.filteredPlaces.isEmpty {
                Color.black.opacity(0.15)
                    .edgesIgnoringSafeArea(.all)
            }
            
            if !isExpanded {
                VStack(spacing: 0) {
                    // App title and control buttons
                    HStack {
                        // Animated title
                        HStack(spacing: 0) {
                            Text("Half")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .offset(x: halfOffset)
                                .scaleEffect(titleScale)
                                .opacity(titleOpacity)
                                
                            Text("way")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .offset(x: wayOffset)
                                .scaleEffect(titleScale)
                                .opacity(titleOpacity)
                        }
                        .contentShape(Rectangle()) // Make the entire area tappable
                        .padding(.leading)
                        .onTapGesture {
                            animateTitle()
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // Map type toggle button
                            Button(action: {
                                mapType = mapType == .standard ? .satellite : .standard
                            }) {
                                Image(systemName: mapType == .standard ? "globe" : "map")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.7))
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            // Expand button
                            Button(action: {
                                withAnimation(.spring(duration: 0.3)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.7))
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                        }
                        .padding(.trailing)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Content panel at the bottom
                    if (viewModel.midpoint == nil || viewModel.filteredPlaces.isEmpty) && 
                       viewModel.searchText.isEmpty && // Only show search panel when not actively searching
                       !viewModel.isSearching { // Make sure we're not in the middle of a search
                        // Redesigned floating search panel
                        searchPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Improved results panel
                        ResultsPanel(
                            viewModel: viewModel,
                            resetLocations: $resetLocations,
                            mapRegion: $mapRegion,
                            isExpanded: $isExpanded,
                            dragOffset: $draggedOffset,
                            minHeight: minDragHeight,
                            maxHeight: maxDragHeight,
                            mapType: mapType,
                            searchText: $searchText
                        )
                        .transition(.opacity)
                        .animation(.spring(), value: viewModel.filteredPlaces)
                        .animation(.spring(), value: searchText)
                    }
                }
            } else {
                // Expanded mode with compact controls
                VStack {
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // Map type toggle button
                            Button(action: {
                                mapType = mapType == .standard ? .satellite : .standard
                            }) {
                                Image(systemName: mapType == .standard ? "globe" : "map")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.7))
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            // Return to Midpoint button with improved implementation
                            Button(action: {
                                if let midpoint = viewModel.midpoint {
                                    // Set map region to focus on midpoint and locations
                                    var allPoints: [CLLocationCoordinate2D] = [midpoint]
                                    if !viewModel.locations.isEmpty {
                                        allPoints.append(contentsOf: viewModel.locations.map { $0.coordinate })
                                    }
                                    
                                    // Calculate region that fits all points
                                    withAnimation(.easeInOut) {
                                        mapRegion = calculateRegion(for: allPoints)
                                    }
                                    
                                    // Force MapView to reset user interaction state
                                    // This is a workaround to ensure the MapView properly responds
                                    DispatchQueue.main.async {
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("ResetMapInteraction"),
                                            object: nil
                                        )
                                    }
                                }
                            }) {
                                Image(systemName: "location")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.7))
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            // Collapse button
                            Button(action: {
                                withAnimation(.spring(duration: 0.3)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.7))
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                        }
                        .padding(.trailing)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
            
            // Update loading overlay with blur effect instead of blue
            if viewModel.isSearching {
                ZStack {
                    // Blur background effect
                    BlurView(style: .systemMaterialDark)
                        .opacity(0.95)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Dark overlay for better text contrast
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                }
                
                VStack(spacing: 20) {
                    // Animated title for loading state
                    HStack(spacing: 0) {
                        Text("Half")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: halfOffset)
                            .scaleEffect(titleScale)
                            .opacity(titleOpacity)
                            
                        Text("way")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: wayOffset)
                            .scaleEffect(titleScale)
                            .opacity(titleOpacity)
                    }
                    
                    // Add a subtitle that cycles through different alternatives
                    Text(loadingSubtitles[currentSubtitleIndex])
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .opacity(subtitleOpacity)
                        .transition(.opacity)
                    
                    // Improved progress indicator
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.top, 10)
                }
                .onAppear {
                    // Start animations when loading begins
                    animateLoadingTitle()
                    startSubtitleAnimation()
                }
            }
        }
        .sheet(isPresented: $isLocationSearching) {
            LocationSearchView(searchText: "", onLocationSelected: { location in
                if searchFor < viewModel.locations.count {
                    viewModel.setLocation(at: searchFor, to: location)
                } else {
                    viewModel.addLocation(location)
                }
                isLocationSearching = false
            }, onUseCurrentLocation: {
                viewModel.useCurrentLocation(at: searchFor)
                isLocationSearching = false
            })
        }
        .sheet(item: $viewModel.showingPlaceDetail) { place in
            PlaceDetailView(place: place, locations: viewModel.locations)
        }
        .sheet(item: $locationFromMap) { location in
            // Confirmation sheet for adding a location from the map
            VStack(spacing: 16) {
                Text("Add Location")
                    .font(.headline)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Name:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(location.name)
                        .font(.body)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        locationFromMap = nil
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.large)
                    
                    Button("Add to Location \(viewModel.locations.count + 1)") {
                        // Add the location to the proper slot
                        let index = min(2, viewModel.locations.count)
                        switch index {
                        case 0:
                            viewModel.setLocation1(location)
                        case 1:
                            viewModel.setLocation2(location)
                        case 2:
                            viewModel.addLocation(location)
                        default:
                            break
                        }
                        
                        // Clear the locationFromMap to dismiss the sheet
                        locationFromMap = nil
                        
                        // Update the map region to focus on the added location
                        withAnimation {
                            mapRegion = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        }
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .controlSize(.large)
                    .tint(.indigo)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .frame(height: 220) // Fixed height instead of presentation detents
        }
        .alert(viewModel.errorMessage ?? "An error occurred", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        }
        .onAppear {
            // Set initial map region to user's location if available
            if let userLocation = viewModel.userLocation?.coordinate {
                mapRegion = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
            
            // Add publisher to observe midpoint changes
            viewModel.$midpoint
                .compactMap { $0 } // Only proceed when midpoint is not nil
                .sink { midpoint in
                    // Update map region when midpoint changes
                    withAnimation {
                        self.mapRegion = MKCoordinateRegion(
                            center: midpoint,
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        )
                    }
                }
                .store(in: &cancellableStore.set)
            
            // Set up notification observers
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AddLocationFromMap"), 
                object: nil, 
                queue: .main
            ) { notification in
                if let location = notification.object as? Location {
                    // Only show the sheet if we have room for more locations (max 3)
                    if viewModel.locations.count < 3 {
                        locationFromMap = location
                    }
                }
            }
            
            if viewModel.locations.isEmpty {
                animateTitle()
            }
        }
    }
    
    // Function to handle the title animation
    func animateTitle() {
        guard !isTitleAnimating else { return }
        
        isTitleAnimating = true
        titleOpacity = 1.0
        
        // First animation - separate the words
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2)) {
            halfOffset = -30
            wayOffset = 30
            titleScale = 1.2
        }
        
        // Second animation - bounce back with slight overshoot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1)) {
                halfOffset = -5
                wayOffset = 5
            }
        }
        
        // Third animation - return to original state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)) {
                halfOffset = 0
                wayOffset = 0
                titleScale = 1.0
            }
            
            // Reset animation state after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isTitleAnimating = false
            }
        }
    }
    
    // Redesigned floating search panel
    var searchPanel: some View {
        VStack(spacing: 16) {
            // Modern card design with shadow and blur background
            VStack(spacing: 20) {
                Text("Find places halfway between locations")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                // Location inputs with better styling
                VStack(spacing: 12) {
                    ForEach(0..<min(viewModel.locations.count + 1, viewModel.canAddLocation ? viewModel.locations.count + 1 : viewModel.locations.count), id: \.self) { index in
                        let isNewLocation = index == viewModel.locations.count
                        let location = isNewLocation ? nil : viewModel.locations[index]
                        
                        locationInputRow(
                            index: index,
                            location: location,
                            isNewLocation: isNewLocation
                        )
                    }
                }
                
                // Find Meeting Places button with clean Apple-style
                FindMeetingPlacesButton(isDisabled: viewModel.locations.isEmpty) {
                    // Only search when button is explicitly clicked
                    viewModel.searchPlacesAroundMidpoint()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 25)
        }
    }
    
    // Location input row with add/remove capabilities
    func locationInputRow(index: Int, location: Location?, isNewLocation: Bool) -> some View {
        HStack {
            // Location icon with index number 
            ZStack {
                Circle()
                    .fill(locationColor(for: index))
                    .frame(width: 32, height: 32)
                
                if isNewLocation {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            if isNewLocation {
                // "Add location" button
                Button(action: {
                    isLocationSearching = true
                    searchFor = index
                }) {
                    HStack {
                        Text(index == 0 ? "Add a location" : "Add another location")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .frame(height: 36)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
            } else {
                // Location input button
                Button(action: {
                    searchFor = index
                    isLocationSearching = true
                }) {
                    HStack {
                        Text(location?.name ?? "Enter location")
                            .lineLimit(1)
                            .font(.system(size: 15))
                            .foregroundColor(location != nil ? .primary : .secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .frame(height: 36)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
                
                // Menu for location options
                Menu {
                    Button(action: {
                        searchFor = index
                        isLocationSearching = true
                    }) {
                        Label("Change location", systemImage: "mappin")
                    }
                    
                    Button(action: {
                        viewModel.useCurrentLocation(at: index)
                    }) {
                        Label("Use current location", systemImage: "location.fill")
                    }
                    
                    if viewModel.locations.count > 2 {
                        Button(role: .destructive, action: {
                            withAnimation {
                                viewModel.removeLocation(at: index)
                            }
                        }) {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
                .padding(.leading, 4)
            }
        }
    }
    
    // Helper to get location color based on index
    func locationColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink]
        return index < colors.count ? colors[index] : .gray
    }
    
    // Reusable location input button with improved styling (keeping for backward compatibility)
    func locationInputButton(icon: String, iconColor: Color, text: String, hasValue: Bool, action: @escaping () -> Void, clearAction: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            Button(action: action) {
                HStack {
                    Text(text)
                        .lineLimit(1)
                        .font(.system(size: 15))
                        .foregroundColor(hasValue ? .primary : .secondary)
                        .padding(.leading, 8)
                    Spacer()
                }
                .contentShape(Rectangle())
                .frame(height: 36)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
            
            if hasValue {
                Button(action: clearAction) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
                .padding(.horizontal, 8)
            }
        }
    }
    
    // Add a helper function to calculate region that fits all points
    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else { 
            return mapRegion 
        }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Add padding
        let latPadding = (maxLat - minLat) * 1.3
        let lonPadding = (maxLon - minLon) * 1.3
        
        // Ensure minimum span size
        let latDelta = max(latPadding, 0.02)
        let lonDelta = max(lonPadding, 0.02)
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
    
    // Helper to find the MapView coordinator
    private func findMapView() -> MapView.Coordinator? {
        // This is a shortcut to access the MapView coordinator directly
        // In a real app, you might want to use a more robust approach
        return nil
    }
    
    // Function to animate the loading title (enhancement of existing animateTitle function)
    func animateLoadingTitle() {
        guard !isTitleAnimating else { return }
        
        isTitleAnimating = true
        titleOpacity = 1.0
        
        // First animation - separate the words
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2)) {
            halfOffset = -30
            wayOffset = 30
            titleScale = 1.2
        }
        
        // Second animation - bounce back with slight overshoot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1)) {
                halfOffset = -5
                wayOffset = 5
            }
        }
        
        // Third animation - return to original state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)) {
                halfOffset = 0
                wayOffset = 0
                titleScale = 1.0
            }
            
            // Loop the animation for continuous effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isTitleAnimating = false
                if viewModel.isSearching {
                    animateLoadingTitle() // Loop if still loading
                }
            }
        }
    }
    
    // Function to cycle through different subtitles during loading
    func startSubtitleAnimation() {
        // Create a repeating timer that changes the subtitle every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            guard viewModel.isSearching else {
                timer.invalidate()
                return
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                subtitleOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentSubtitleIndex = (currentSubtitleIndex + 1) % loadingSubtitles.count
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    subtitleOpacity = 1.0
                }
            }
        }
    }
}

struct ResultsPanel: View {
    @ObservedObject var viewModel: HalfwayViewModel
    @Binding var resetLocations: Bool
    @Binding var mapRegion: MKCoordinateRegion
    @Binding var isExpanded: Bool
    @Binding var dragOffset: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let mapType: MKMapType
    @Binding var searchText: String
    
    // Add state for controlling search overlay visibility
    @State private var showSearchOverlay = false
    // Add state to track if keyboard is shown
    @State private var isKeyboardVisible = false
    // Add state to track active searching (when text is not empty)
    private var isActivelySearching: Bool {
        return !searchText.isEmpty
    }
    // Store previous category selection
    @State private var previousCategory: PlaceCategory? = nil
    
    @State private var isDragging = false
    @State private var dragState = CGSize.zero
    
    init(viewModel: HalfwayViewModel, 
         resetLocations: Binding<Bool>,
         mapRegion: Binding<MKCoordinateRegion>,
         isExpanded: Binding<Bool>,
         dragOffset: Binding<CGFloat>,
         minHeight: CGFloat,
         maxHeight: CGFloat,
         mapType: MKMapType,
         searchText: Binding<String>) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        _resetLocations = resetLocations
        _mapRegion = mapRegion
        _isExpanded = isExpanded
        _dragOffset = dragOffset
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.mapType = mapType
        _searchText = searchText
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Floating card similar to search panel (not stretched to edges)
            VStack(spacing: 0) {
                // Only show the header and minimap when not actively searching or keyboard is not visible
                if !isKeyboardVisible {
                    headerView
                }
                searchBarView
                
                // Only show these components when keyboard is not visible
                if !isKeyboardVisible {
                    miniMapView
                    radiusControlView
                    // Only show category filter when not actively searching
                    if !isActivelySearching {
                        categorySelectionView
                    }
                }
                
                // Adjusted placeListView that adapts based on keyboard visibility
                if isKeyboardVisible {
                    // When keyboard is visible, only show search results in a more compact form
                    placeListViewCompact
                } else {
                    // Regular place list view when keyboard is not visible
                    placeListView
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
            )
            .offset(y: dragState.height)
            // Add drag gesture to allow returning to search
            .gesture(dragGesture)
        }
        // Adjust height based on keyboard visibility
        .frame(maxHeight: isKeyboardVisible ? min(UIScreen.main.bounds.height * 0.5, 350) : UIScreen.main.bounds.height * 0.9)
        .edgesIgnoringSafeArea(.bottom)
        // Add keyboard notifications to adjust UI when keyboard appears
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    isKeyboardVisible = true
                }
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    isKeyboardVisible = false
                }
            }
            // Store initial category selection
            previousCategory = viewModel.selectedCategory
        }
        .onChange(of: viewModel.selectedCategory) { newCategory in
            previousCategory = newCategory
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if isKeyboardVisible {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isKeyboardVisible = false
                            hideKeyboard()
                        }
                    }
                }
        )
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        HStack {
            Button(action: {
                withAnimation {
                    // Clear places and return to search
                    viewModel.filteredPlaces = []
                    viewModel.places = []
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                // Results header with count
                Text("\(viewModel.filteredPlaces.count) places found")
                    .font(.headline)
                    .fontWeight(.bold)
                
                // Show the number of locations with more context
                if viewModel.locations.isEmpty {
                    Text("No locations selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if viewModel.locations.count == 1 {
                    Text("1 location selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(viewModel.locations.count) locations selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // Enhanced search bar with modern design - add Done button when keyboard is visible
    private var searchBarView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search", text: $searchText, onEditingChanged: { isEditing in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isKeyboardVisible = isEditing
                    }
                })
                .frame(height: 36)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                if isKeyboardVisible {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isKeyboardVisible = false
                            hideKeyboard()
                        }
                    }) {
                        Text("Done")
                            .foregroundColor(.accentColor)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Add horizontal scroll for common search categories when keyboard is visible
            if isKeyboardVisible {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(["Restaurant", "Cafe", "Bar", "Park", "Food", "Coffee", "Drinks"], id: \.self) { category in
                            Button(action: {
                                searchText = category.lowercased()
                            }) {
                                Text(category)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var miniMapView: some View {
        // Mini map area to show overview - update to use midpoint for region center
        ZStack {
            // Create a local MapView with a region centered on the midpoint
            if let midpoint = viewModel.midpoint {
                MapView(region: $mapRegion, 
                        locations: viewModel.locations,
                        midpoint: midpoint,
                        places: viewModel.filteredPlaces,
                        searchRadius: viewModel.searchRadius,
                        selectedPlace: Binding(
                            get: { viewModel.showingPlaceDetail },
                            set: { viewModel.showingPlaceDetail = $0 }
                        ),
                        isExpanded: false,
                        resetLocations: $resetLocations,
                        mapType: mapType)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Overlay text for map expansion with improved visibility
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Tap to expand map")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(12)
                    }
                }
            } else {
                Text("Map not available")
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(height: 160)
        .contentShape(Rectangle()) // Makes the entire area tappable
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .onTapGesture {
            withAnimation(.spring(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var radiusControlView: some View {
        // Radius slider control with improved styling
        VStack(alignment: .leading) {
            HStack {
                Text("Search Radius: \(viewModel.searchRadius, specifier: "%.1f") km")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Dynamic slider that adapts to max distance
            Slider(value: Binding(
                get: { viewModel.searchRadius },
                set: { viewModel.updateSearchRadius($0) }
            ), in: 0.5...viewModel.maxSearchRadius, step: 0.1)
                .padding(.horizontal, 20)
                .accentColor(.black)
                .animation(nil, value: viewModel.searchRadius) // Removes animation on slider itself
                .onChange(of: viewModel.maxSearchRadius) { newMax in
                    // Make sure search radius is within bounds when max changes
                    if viewModel.searchRadius > newMax {
                        viewModel.searchRadius = newMax
                    }
                }
        }
        .padding(.bottom, 12)
    }
    
    private var categorySelectionView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filter by Category")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // All Categories Button
                    CategoryFilterButton(
                        title: "All",
                        icon: "line.3.horizontal.decrease.circle",
                        isSelected: viewModel.selectedCategory == nil,
                        action: {
                            viewModel.selectedCategory = nil
                            previousCategory = nil
                            viewModel.filterPlacesWithCurrentSettings()
                        }
                    )
                    
                    // Category Buttons
                    ForEach(PlaceCategory.allCases, id: \.self) { category in
                        CategoryFilterButton(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: viewModel.selectedCategory == category,
                            action: {
                                // To prevent UI issues, let's directly use the viewModel's filterByCategory method
                                // which has been updated to safely handle category expansion
                                viewModel.filterByCategory(category)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Divider()
                .padding(.horizontal, 20)
        }
    }
    
    // Custom filter button component
    struct CategoryFilterButton: View {
        let title: String
        let icon: String
        let isSelected: Bool
        let action: () -> Void
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? 
                              Color.accentColor : 
                              (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)))
                )
                .foregroundColor(isSelected ? .white : .primary)
            }
            .buttonStyle(ScalingButtonStyle())
        }
    }
    
    private var placeListView: some View {
        VStack(spacing: 0) {
            HStack {
                // Conditionally show different header based on search
                if isActivelySearching {
                    Text("Search Results")
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("Results")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if !viewModel.filteredPlaces.isEmpty {
                    Text("\(viewModel.filteredPlaces.count) \(viewModel.filteredPlaces.count == 1 ? "result" : "results")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            if viewModel.filteredPlaces.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    if isActivelySearching {
                        Text("No matches found for \"\(searchText)\"")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Try a different search term or clear filters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Add a button to clear search
                        Button(action: {
                            searchText = ""
                            viewModel.searchText = ""
                            viewModel.filterPlacesWithCurrentSettings()
                        }) {
                            Text("Clear Search")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.8))
                                )
                        }
                        .padding(.top, 8)
                    } else {
                        Text("No matching places found")
                            .foregroundColor(.secondary)
                        Text("Try adjusting your search or filters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredPlaces, id: \.id) { place in
                            PlaceRow(place: place, midpoint: viewModel.midpoint)
                                .onTapGesture {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    viewModel.showingPlaceDetail = place
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // A more compact view for search results when keyboard is visible
    private var placeListViewCompact: some View {
        VStack(spacing: 0) {
            if viewModel.filteredPlaces.isEmpty {
                if isActivelySearching {
                    // Very compact "no results" view
                    HStack {
                        Text("No matches found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            searchText = ""
                            viewModel.searchText = ""
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Text("Clear")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                }
            } else {
                // Show a small scrollable list of results
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredPlaces.prefix(5), id: \.id) { place in
                            PlaceRowCompact(place: place, onTap: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.selectedPlace = place
                                    viewModel.keyboardVisible = false
                                    hideKeyboard()
                                }
                            })
                            .padding(.horizontal)
                            Divider()
                                .padding(.horizontal)
                        }
                        
                        if viewModel.filteredPlaces.count > 5 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.keyboardVisible = false
                                    hideKeyboard()
                                }
                            }) {
                                Text("See all \(viewModel.filteredPlaces.count) results")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .frame(maxHeight: 200)
            }
        }
        .background(
            // Add tap area outside search results to dismiss
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
    
    // A compact row for search results when keyboard is visible
    struct PlaceRowCompact: View {
        let place: Place
        let onTap: () -> Void
        
        var body: some View {
            HStack(spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(Color(UIColor(named: place.category.color) ?? .gray).opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: place.category.icon)
                        .font(.system(size: 15))
                        .foregroundColor(Color(UIColor(named: place.category.color) ?? .gray))
                }
                
                // Place name
                Text(place.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .opacity(0.7)
            }
            .padding(.vertical, 8)
            .background(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Dismiss keyboard when dragging
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                isDragging = true
                // Only allow dragging down
                let newHeight = max(0, value.translation.height)
                dragState = CGSize(width: 0, height: newHeight)
            }
            .onEnded { value in
                isDragging = false
                // If dragged down far enough, return to search screen
                if dragState.height > 100 {
                    withAnimation(.spring()) {
                        // Clear places but keep locations
                        viewModel.filteredPlaces = []
                        viewModel.places = []
                        // Don't modify search text when dragging
                    }
                } else {
                    // Snap back
                    withAnimation(.spring()) {
                        dragState = .zero
                    }
                }
            }
    }
    
    // MARK: - Helper Functions
    
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return from.distance(from: to)
    }
    
    // Common search categories for better discoverability
    private var commonSearchCategories = [
        "Restaurant", 
        "Coffee", 
        "Bar", 
        "Hotel", 
        "Park", 
        "Gas Station", 
        "Parking", 
        "Shopping"
    ]
}

// Custom button style for better tap feedback
struct ScalingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Add a new more responsive button style that gives immediate feedback
struct InstantFeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Redesigned Card-style design for place items
struct ImprovedPlaceCard: View {
    let place: Place
    let location1: Location?
    let location2: Location?
    let midpoint: CLLocationCoordinate2D?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Category icon with improved styling
                ZStack {
                    Circle()
                        .fill(Color(UIColor(named: place.category.color) ?? .gray))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: place.category.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Name with better styling
                    Text(place.name)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    
                    // Distance from midpoint with better styling
                    if midpoint != nil {
                        Text("\(formatDistance(place.distanceFromMidpoint)) from midpoint")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                Spacer()
                
                // Chevron indicator for detail
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Travel time section with unified styling for both locations
            HStack(spacing: 0) {
                // Location 1 travel time
                locationTravelTimeView(
                    name: location1?.name ?? "Current Location",
                    drivingTime: place.travelTimeFromLocation1.driving,
                    walkingTime: place.travelTimeFromLocation1.walking,
                    iconColor: .blue
                )
                
                Divider()
                    .frame(height: 24)
                    .background(Color.secondary.opacity(0.3))
                
                // Location 2 travel time
                locationTravelTimeView(
                    name: location2?.name ?? "Current Location",
                    drivingTime: place.travelTimeFromLocation2.driving,
                    walkingTime: place.travelTimeFromLocation2.walking,
                    iconColor: .green
                )
            }
            .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle()) // Make entire card tappable
    }
    
    // Unified travel time view for consistency
    private func locationTravelTimeView(name: String, drivingTime: Int?, walkingTime: Int?, iconColor: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            // Unified styling for location names (including Current Location)
            Text(String(name.prefix(10)))
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                if let driving = drivingTime {
                    LabeledTime(icon: "car.fill", time: "\(driving)m", color: iconColor)
                }
                
                if let walking = walkingTime {
                    LabeledTime(icon: "figure.walk", time: "\(walking)m", color: iconColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.7))
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

// Improved component for labeled time values
struct LabeledTime: View {
    let icon: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(time)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// Helper extensions
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

class CancellableStore: ObservableObject {
    var set = Set<AnyCancellable>()
}

// New Apple-style Find Meeting Places button component
struct FindMeetingPlacesButton: View {
    var isDisabled: Bool
    var action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 16, weight: .medium))
                Text("Find Meeting Places")
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isDisabled ? buttonDisabledColor : buttonEnabledColor)
            )
            .foregroundColor(buttonTextColor)
        }
        .disabled(isDisabled)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
    
    // Clean Apple-style colors based on mode
    private var buttonEnabledColor: Color {
        colorScheme == .dark ? Color(white: 0.25) : Color.black
    }
    
    private var buttonDisabledColor: Color {
        colorScheme == .dark ? Color(white: 0.25).opacity(0.6) : Color.black.opacity(0.6)
    }
    
    private var buttonTextColor: Color {
        if isDisabled {
            return colorScheme == .dark ? Color(white: 0.6) : Color.white.opacity(0.7)
        } else {
            return colorScheme == .dark ? Color(white: 0.9) : Color.white
        }
    }
}

// Add BlurView for iOS
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// Add a background tap gesture to dismiss the keyboard
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
} 