import SwiftUI
import MapKit

struct LocationSearchView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String
    @State private var searchResults: [Location] = []
    @State private var isSearching = false
    
    var onLocationSelected: (Location) -> Void
    var onUseCurrentLocation: () -> Void
    
    init(searchText: String, onLocationSelected: @escaping (Location) -> Void, onUseCurrentLocation: @escaping () -> Void) {
        _searchText = State(initialValue: searchText)
        self.onLocationSelected = onLocationSelected
        self.onUseCurrentLocation = onUseCurrentLocation
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
                
                // Improved search field with immediate responsiveness
                TextField("Search for a location", text: $searchText)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.leading, 4)
                    .autocorrectionDisabled(true) // Disable autocorrection for faster typing
                    .disableAutocorrection(true) // For backward compatibility
                    // Remove debouncing to ensure immediate typing responsiveness
                    .onChange(of: searchText) { newValue in
                        if !newValue.isEmpty {
                            performSearch(query: newValue)
                        } else {
                            searchResults = []
                        }
                    }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            // Current location button
            Button(action: {
                onUseCurrentLocation()
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Use Current Location")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 10)
            }
            
            // Divider
            Divider()
                .padding(.top, 10)
            
            // Loading indicator
            if isSearching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            }
            
            // Search results
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(searchResults, id: \.self) { location in
                        Button(action: {
                            onLocationSelected(location)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            LocationRow(location: location)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .navigationBarHidden(true)
    }
    
    private func performSearch(query: String) {
        isSearching = true
        
        // Use direct MKLocalSearch without debounce to prevent delay
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            guard let response = response, error == nil else {
                searchResults = []
                return
            }
            
            searchResults = response.mapItems.map { item in
                Location(
                    name: item.name ?? "Unknown Location",
                    placemark: item.placemark,
                    coordinate: item.placemark.coordinate
                )
            }
        }
    }
}

struct LocationRow: View {
    let location: Location
    
    var body: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(location.name)
                    .font(.headline)
                if let thoroughfare = location.placemark.thoroughfare,
                   let locality = location.placemark.locality {
                    Text("\(thoroughfare), \(locality)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let locality = location.placemark.locality {
                    Text(locality)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle()) // Make the entire row tappable
        .padding(.vertical, 8)
    }
} 