# Halfway

Halfway is an elegant iOS app that helps you find the perfect meeting places between multiple locations. Ideal for coordinating meetups with friends, family, or colleagues coming from different starting points.

## Features

### Core Functionality
- Support for up to 5 different starting locations
- Smart midpoint calculation based on all locations
- Find places (restaurants, cafes, bars, parks) around the midpoint
- Intuitive and beautiful UI with Apple design language
- Animated transitions and visual feedback

### Search & Filtering
- Enhanced category filtering with horizontal scrolling buttons
- Smart search functionality that understands context (e.g., "food" finds restaurants and cafes)
- Search suggestions with common categories
- Compact search mode when typing with "Done" button and outside-tap dismissal
- Category-specific icons and visual indicators

### User Experience
- Animated launch screen with elegant transitions
- Persistent location history for quick access to frequent locations
- Responsive UI adjustments for keyboard visibility
- Live distance and travel time calculations
- Support for both light and dark mode
- Haptic feedback for important actions

### Map Features
- Interactive map with custom markers and annotations
- Adjustable search radius with visual indicator
- Toggle between standard and satellite map views
- Single-tap directions to selected locations
- Visually pleasing location pins and midpoint marker

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## Installation

1. Clone the repository
2. Open the project in Xcode
3. Build and run on your device or simulator

## Usage

1. Input multiple locations (up to 5)
   - Use your current location with a single tap
   - Search for locations by name, address, or landmark
   - Select from your recent location history
2. The app automatically calculates the ideal midpoint
3. Browse places around the midpoint with intuitive filtering
   - Filter by category (restaurant, cafe, bar, park, other)
   - Search for specific place types or names
   - Adjust search radius as needed
4. Tap on a place to see details:
   - Travel times from all locations
   - Distance from midpoint
   - Category and other relevant information
5. Get directions or share the selected location with your friends

## Technical Details

- Built with SwiftUI and MapKit
- MVVM architecture
- Asynchronous search operations for improved performance
- Semantic location search with category mapping
- Smart throttling for API requests to prevent rate limiting
- Reactive UI updates with Combine framework

## License

This project is licensed under the MIT License - see the LICENSE file for details. 