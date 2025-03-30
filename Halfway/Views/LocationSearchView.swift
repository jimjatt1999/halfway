import SwiftUI
import MapKit

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchResults: [MKMapItem] = []
    @State private var searchText: String
    @State private var isSearching = false
    @State private var searchError: String?
    
    var onLocationSelected: (Location) -> Void
    var onUseCurrentLocation: () -> Void
    
    init(searchText: String, onLocationSelected: @escaping (Location) -> Void, onUseCurrentLocation: @escaping () -> Void) {
        self._searchText = State(initialValue: searchText)
        self.onLocationSelected = onLocationSelected
        self.onUseCurrentLocation = onUseCurrentLocation
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding()
                }
                
                TextField("Search locations", text: $searchText)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: searchText) { newValue in
                        // Debounce search
                        if newValue.count > 2 {
                            searchLocations()
                        } else if newValue.isEmpty {
                            searchResults = []
                        }
                    }
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(Color.white)
            
            // Use current location button
            Button(action: {
                onUseCurrentLocation()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Current Location")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
                .background(Color.white)
            }
            .padding(.top, 1)
            
            if searchError != nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(searchError!)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(Color.white)
            }
            
            if isSearching {
                Spacer()
                ProgressView("Searching...")
                    .padding()
                Spacer()
            } else if searchResults.isEmpty && !searchText.isEmpty && searchError == nil {
                VStack {
                    Spacer()
                    Text("No results found")
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                // Search results
                List {
                    ForEach(searchResults, id: \.self) { item in
                        Button(action: {
                            let location = Location(
                                name: item.name ?? item.placemark.title ?? "Unknown Place",
                                coordinate: item.placemark.coordinate
                            )
                            onLocationSelected(location)
                        }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                VStack(alignment: .leading) {
                                    Text(item.name ?? "Unknown Place")
                                        .font(.headline)
                                    
                                    Text(formatAddress(item.placemark))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private func searchLocations() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            if let error = error {
                print("Error searching for locations: \(error.localizedDescription)")
                searchError = "Search failed: \(error.localizedDescription)"
                searchResults = []
                return
            }
            
            guard let response = response else {
                searchError = "No results found"
                searchResults = []
                return
            }
            
            // Limit to 15 results for better performance
            self.searchResults = Array(response.mapItems.prefix(15))
            
            if self.searchResults.isEmpty {
                // No results feedback is handled in the view
            }
        }
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String {
        var addressComponents: [String] = []
        
        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }
        
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        if addressComponents.isEmpty {
            if let name = placemark.name {
                return name
            } else {
                return "Unknown location"
            }
        }
        
        return addressComponents.joined(separator: ", ")
    }
} 