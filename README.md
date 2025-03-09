# Halfway

A minimalistic but intuitive web app that helps people find interesting meeting places halfway between two locations.

## Features

- Enter two locations to find meeting spots in between
- View points of interest (cafes, restaurants, shops, etc.) that are approximately halfway between both locations
- Interactive map visualization using Leaflet and OpenStreetMap
- Responsive design for mobile and desktop use

## Technology Stack

- React with TypeScript
- Leaflet for maps
- OpenStreetMap and Overpass API for location data
- Axios for API requests

## Setup

1. Clone the repository
```bash
git clone https://github.com/jimjatt1999/halfway.git
cd halfway
```

2. Install dependencies
```bash
npm install
```

3. Start the development server
```bash
npm start
```

4. Build for production
```bash
npm run build
```

## How It Works

The app calculates the midpoint between two addresses and then finds points of interest near that midpoint using the Overpass API. This allows two people to meet at a convenient location that requires approximately equal travel time for both.

## License

MIT
