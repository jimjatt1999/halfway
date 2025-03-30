# Halfway

Halfway is an iOS app that helps you find meeting places that are halfway between two locations. Perfect for meeting up with friends or colleagues when you're coming from different places.

## Features

- Enter two different locations
- Calculate the midpoint between them
- Find places (restaurants, cafes, bars, parks) within a specified radius around the midpoint
- Filter places by category
- View travel times (driving & walking) from both locations
- Get directions to the selected place
- Coordinate meetups with the "Meet Now" feature

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Installation

1. Clone the repository
2. Open the project in Xcode
3. Build and run on your device or simulator

## Usage

1. Input two locations (you can use your current location for one of them)
2. Tap "Find Meeting Places" to see places located halfway between the two points
3. Filter by category if needed (restaurant, cafe, bar, park)
4. Adjust the search radius if needed
5. Tap on a place to see details, including travel times from both locations
6. Use the "Directions" button to get directions to the selected place

## Permissions

The app requires:
- Location access (when in use) to determine your current location
- Access to Apple Maps for directions

## Technical Details

- Built with SwiftUI and MapKit
- MVVM architecture
- Uses Core Location for user location
- Uses MKLocalSearch for finding places

## License

This project is licensed under the MIT License - see the LICENSE file for details. 