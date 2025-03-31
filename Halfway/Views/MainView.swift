import SwiftUI
import MapKit
import Combine

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
                            // Add map type toggle button on home screen
                            Button(action: {
                                mapType = mapType == .standard ? .satellite : .standard
                            }) {
                                Image(systemName: mapType == .standard ? "globe" : "map")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.indigo)
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
                                            .fill(Color.indigo)
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            // Only show reset button when locations exist
                            if viewModel.location1 != nil || viewModel.location2 != nil {
                                Button(action: {
                                    withAnimation {
                                        // Modified: Instead of clearing everything, just clear places to return to search
                                        viewModel.filteredPlaces = []
                                        viewModel.places = []
                                    }
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(Color.indigo)
                                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                        )
                                }
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
                                            .fill(Color.indigo)
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            // Reset button
                            Button(action: {
                                withAnimation {
                                    resetLocations = true
                                    viewModel.clearLocation1()
                                    viewModel.clearLocation2()
                                    viewModel.filteredPlaces = []
                                    viewModel.places = []
                                    
                                    // Return to search view when clearing
                                    isExpanded = false
                                }
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.indigo)
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
                                            .fill(Color.indigo)
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
            
            // Overlay for loading state
            if viewModel.isSearching {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .scaleEffect(2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
        }
    }
    
    // Function to handle the title animation
    func animateTitle() {
        guard !isTitleAnimating else { return }
        
        isTitleAnimating = true
        
        // First animation - separate the words
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2)) {
            halfOffset = -20
            wayOffset = 20
            titleScale = 1.2
        }
        
        // Second animation - bounce back with slight overshoot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1)) {
                halfOffset = -5
                wayOffset = 5
            }
        }
        
        // Third animation - return to original state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)) {
                halfOffset = 0
                wayOffset = 0
                titleScale = 1.0
            }
            
            // Reset animation state after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                
                // Find Meeting Places button with improved styling
                Button(action: {
                    viewModel.searchPlacesAroundMidpoint()
                }) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Find Meeting Places")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(viewModel.locations.isEmpty ? 
                                  Color.indigo.opacity(0.6) : Color.indigo)
                    )
                    .foregroundColor(.white)
                }
                .disabled(viewModel.locations.isEmpty)
                .animation(.easeInOut(duration: 0.2), value: viewModel.locations.isEmpty)
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
                        Text("Add another location")
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
                headerView
                searchBarView // Added inline search bar
                miniMapView
                radiusControlView
                // Only show category filter when not actively searching
                if !isActivelySearching {
                    categorySelectionView
                }
                placeListView
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
        // Fixed height without dragging
        .frame(maxHeight: UIScreen.main.bounds.height * 0.9) // Increase to ensure it extends to bottom
        .edgesIgnoringSafeArea(.bottom)
        // Add keyboard notifications to adjust UI when keyboard appears
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                isKeyboardVisible = true
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                isKeyboardVisible = false
            }
            // Store initial category selection
            previousCategory = viewModel.selectedCategory
        }
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
    
    // New inline search bar that's always visible at the top
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search places...", text: $searchText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onSubmit {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onChange(of: searchText) { newValue in
                    viewModel.searchText = newValue
                    viewModel.filterPlacesWithCurrentSettings()
                    
                    // If starting to search, remember the filter
                    if !newValue.isEmpty && previousCategory == nil {
                        previousCategory = viewModel.selectedCategory
                    }
                    
                    // If clearing search, restore previous filter
                    if newValue.isEmpty && viewModel.selectedCategory == nil && previousCategory != nil {
                        viewModel.selectedCategory = previousCategory
                        viewModel.filterPlacesWithCurrentSettings()
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.searchText = ""
                    
                    // Restore previous filter when clearing search
                    if previousCategory != nil {
                        viewModel.selectedCategory = previousCategory
                    }
                    viewModel.filterPlacesWithCurrentSettings()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
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
                
                Button(action: {
                    // Clear results but keep locations
                    viewModel.filteredPlaces = []
                    viewModel.places = []
                    searchText = ""
                    viewModel.searchText = ""
                    viewModel.searchPlacesAroundMidpoint()
                }) {
                    Text("Reset Search")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.indigo)
                }
            }
            .padding(.horizontal, 20)
            
            // Dynamic slider that adapts to max distance
            Slider(value: Binding(
                get: { viewModel.searchRadius },
                set: { viewModel.updateSearchRadius($0) }
            ), in: 0.5...viewModel.maxSearchRadius, step: 0.1)
                .padding(.horizontal, 20)
                .accentColor(.indigo)
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
        VStack {
            Menu {
                Button("All Categories") {
                    viewModel.selectedCategory = nil
                    previousCategory = nil // Update previous category
                    viewModel.filterPlacesWithCurrentSettings()
                }
                
                ForEach(PlaceCategory.allCases, id: \.self) { category in
                    Button(action: {
                        viewModel.selectedCategory = category
                        previousCategory = category // Update previous category
                        viewModel.filterPlacesWithCurrentSettings()
                    }) {
                        HStack {
                            Text(category.rawValue)
                            Spacer()
                            if viewModel.selectedCategory == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.selectedCategory?.rawValue ?? "Filter by Category")
                        .font(.subheadline)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .animation(.easeInOut, value: viewModel.selectedCategory)
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.horizontal, 20)
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
                                        .fill(Color.indigo)
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
        // Add extra padding at bottom when keyboard is visible
        .padding(.bottom, isKeyboardVisible ? 260 : 0)
        .animation(.easeOut, value: isKeyboardVisible)
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