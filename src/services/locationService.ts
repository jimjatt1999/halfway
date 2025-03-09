import axios from 'axios';
import { LocationCoordinates, LocationAddress, PointOfInterest, PoiCategory } from '../types';

// OpenStreetMap Nominatim API for geocoding
const NOMINATIM_API = 'https://nominatim.openstreetmap.org/search';
// Overpass API for POI search
const OVERPASS_API = 'https://overpass-api.de/api/interpreter';

/**
 * Convert an address string to coordinates using OpenStreetMap Nominatim
 */
export const geocodeAddress = async (address: string): Promise<LocationAddress> => {
  try {
    const response = await axios.get(NOMINATIM_API, {
      params: {
        q: address,
        format: 'json',
        limit: 1,
      },
      headers: {
        'User-Agent': 'Halfway App (https://github.com/jimjatt1999/halfway)'
      }
    });

    if (response.data && response.data.length > 0) {
      const location = response.data[0];
      return {
        name: address,
        displayName: location.display_name,
        coordinates: {
          lat: parseFloat(location.lat),
          lng: parseFloat(location.lon)
        }
      };
    }
    throw new Error('Location not found');
  } catch (error) {
    console.error('Error geocoding address:', error);
    throw new Error('Failed to geocode address');
  }
};

/**
 * Calculate the midpoint between two coordinates
 */
export const calculateMidpoint = (point1: LocationCoordinates, point2: LocationCoordinates): LocationCoordinates => {
  return {
    lat: (point1.lat + point2.lat) / 2,
    lng: (point1.lng + point2.lng) / 2
  };
};

/**
 * Calculate distance between two points in kilometers using the Haversine formula
 */
export const calculateDistance = (point1: LocationCoordinates, point2: LocationCoordinates): number => {
  const R = 6371; // Radius of the Earth in km
  const dLat = (point2.lat - point1.lat) * Math.PI / 180;
  const dLng = (point2.lng - point1.lng) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(point1.lat * Math.PI / 180) * Math.cos(point2.lat * Math.PI / 180) * 
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

/**
 * Map categories to Overpass API tags
 */
const categoryToTags = {
  cafe: ['amenity=cafe', 'amenity=coffee_shop'],
  restaurant: ['amenity=restaurant', 'amenity=fast_food', 'amenity=food_court'],
  bar: ['amenity=bar', 'amenity=pub', 'amenity=nightclub'],
  park: ['leisure=park', 'leisure=garden', 'leisure=playground'],
  library: ['amenity=library'],
  museum: ['tourism=museum', 'tourism=gallery'],
  shop: ['shop'],
  cinema: ['amenity=cinema']
};

/**
 * Find points of interest near a specific point using a simplified approach
 */
export const findPointsOfInterest = async (
  center: LocationCoordinates,
  radius: number = 1000, // 1 km radius
  categories: PoiCategory[] = ['cafe', 'restaurant', 'bar', 'shop']
): Promise<PointOfInterest[]> => {
  try {
    // We'll start with a very simple approach for Japan
    let query = `
      [out:json][timeout:90];
      (
    `;
    
    // Build a simpler query that looks for all amenities and shops
    // in a radius around the midpoint
    if (categories.includes('shop')) {
      query += `
        // All shops
        node["shop"](around:${radius}, ${center.lat}, ${center.lng});
        way["shop"](around:${radius}, ${center.lat}, ${center.lng});
      `;
    }
    
    if (categories.some(c => ['cafe', 'restaurant', 'bar'].includes(c))) {
      query += `
        // Food and drink
        node["amenity"="cafe"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"="cafe"](around:${radius}, ${center.lat}, ${center.lng});
        node["amenity"="restaurant"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"="restaurant"](around:${radius}, ${center.lat}, ${center.lng});
        node["amenity"="fast_food"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"="fast_food"](around:${radius}, ${center.lat}, ${center.lng});
        node["amenity"="bar"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"="bar"](around:${radius}, ${center.lat}, ${center.lng});
        node["amenity"="pub"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"="pub"](around:${radius}, ${center.lat}, ${center.lng});
      `;
    }
    
    if (categories.includes('park')) {
      query += `
        // Parks and recreation
        node["leisure"="park"](around:${radius}, ${center.lat}, ${center.lng});
        way["leisure"="park"](around:${radius}, ${center.lat}, ${center.lng});
        node["leisure"="garden"](around:${radius}, ${center.lat}, ${center.lng});
        way["leisure"="garden"](around:${radius}, ${center.lat}, ${center.lng});
      `;
    }
    
    if (categories.some(c => ['library', 'museum', 'cinema'].includes(c))) {
      query += `
        // Entertainment and culture
        node["amenity"="library"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"="library"](around:${radius}, ${center.lat}, ${center.lng});
        node["tourism"="museum"](around:${radius}, ${center.lat}, ${center.lng});
        way["tourism"="museum"](around:${radius}, ${center.lat}, ${center.lng});
        node["amenity"="cinema"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"="cinema"](around:${radius}, ${center.lat}, ${center.lng});
        node["amenity"="arts_centre"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"="arts_centre"](around:${radius}, ${center.lat}, ${center.lng});
      `;
    }
    
    // If no specific categories selected, or as a fallback if we have a large search radius
    if (categories.length === 0 || radius >= 3000) {
      query += `
        // Fallback - general interesting places
        node["amenity"](around:${radius}, ${center.lat}, ${center.lng});
        way["amenity"](around:${radius}, ${center.lat}, ${center.lng});
        node["tourism"](around:${radius}, ${center.lat}, ${center.lng});
        way["tourism"](around:${radius}, ${center.lat}, ${center.lng});
        node["shop"](around:${radius}, ${center.lat}, ${center.lng});
        way["shop"](around:${radius}, ${center.lat}, ${center.lng});
      `;
    }
    
    // Complete the query
    query += `
      );
      out center body;
    `;
    
    console.log("Simplified query:", query);
    
    // Make the request to Overpass API
    const response = await axios.post(OVERPASS_API, query, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });
    
    console.log(`API found ${response.data?.elements?.length || 0} elements`);
    
    // Process the response
    if (response.data && response.data.elements && response.data.elements.length > 0) {
      // Filter for elements with tags (to make sure they're meaningful POIs)
      const pois = response.data.elements
        .filter((element: any) => {
          // Only include elements with useful tags
          return element.tags && (
            element.tags.name || 
            element.tags.amenity || 
            element.tags.shop || 
            element.tags.tourism ||
            element.tags.leisure
          );
        })
        .map((element: any) => {
          // Extract coordinates (handling both nodes and ways/relations with center points)
          let lat = element.lat;
          let lng = element.lon;
          
          // For ways and relations that use the center property
          if ((!lat || !lng) && element.center) {
            lat = element.center.lat;
            lng = element.center.lon;
          }
          
          // Skip elements without coordinates
          if (!lat || !lng) return null;
          
          // Build the POI object
          const poi: PointOfInterest = {
            id: element.id,
            name: element.tags.name || getDefaultName(element.tags),
            type: getPoiType(element.tags),
            coordinates: {
              lat: lat,
              lng: lng
            },
            address: formatPoiAddress(element.tags),
            distance: calculateDistance(center, { lat, lng })
          };
          return poi;
        })
        .filter((poi: PointOfInterest | null) => poi !== null) // Remove null values
        .sort((a: PointOfInterest, b: PointOfInterest) => 
          (a.distance || 0) - (b.distance || 0) // Sort by distance
        );
      
      // If we have too many results, limit to the 50 closest
      return pois.slice(0, 50);
    }
    
    // If the primary approach yielded no results, try a fallback with minimal filtering
    console.log("No results found, trying super simple fallback query");
    
    // Use a very basic query that just looks for anything with a name
    const fallbackQuery = `
      [out:json][timeout:90];
      (
        node["name"](around:${radius}, ${center.lat}, ${center.lng});
        way["name"](around:${radius}, ${center.lat}, ${center.lng});
      );
      out center body;
    `;
    
    const fallbackResponse = await axios.post(OVERPASS_API, fallbackQuery, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });
    
    console.log(`Fallback API found ${fallbackResponse.data?.elements?.length || 0} elements`);
    
    if (fallbackResponse.data && fallbackResponse.data.elements && fallbackResponse.data.elements.length > 0) {
      const fallbackPois = fallbackResponse.data.elements
        .map((element: any) => {
          // Extract coordinates
          let lat = element.lat;
          let lng = element.lon;
          
          // For ways and relations with center property
          if ((!lat || !lng) && element.center) {
            lat = element.center.lat;
            lng = element.center.lon;
          }
          
          // Skip elements without coordinates
          if (!lat || !lng) return null;
          
          // Build a basic POI object
          return {
            id: element.id,
            name: element.tags.name || 'Unnamed Place',
            type: getPoiType(element.tags) || 'Place',
            coordinates: {
              lat: lat,
              lng: lng
            },
            address: formatPoiAddress(element.tags),
            distance: calculateDistance(center, { lat, lng })
          };
        })
        .filter((poi: PointOfInterest | null) => poi !== null)
        .sort((a: PointOfInterest, b: PointOfInterest) => 
          (a.distance || 0) - (b.distance || 0)
        );
      
      // Limit results 
      return fallbackPois.slice(0, 50);
    }
    
    // If no places found via either approach
    console.log("No places found via any method");
    return [];
  } catch (error) {
    console.error('Error finding points of interest:', error);
    if (error instanceof Error) {
      console.error('Error details:', error.message);
    }
    throw new Error('Failed to find points of interest');
  }
};

/**
 * Get a default name for POIs without a name tag
 */
const getDefaultName = (tags: any): string => {
  if (tags.amenity === 'cafe') return 'Cafe';
  if (tags.amenity === 'restaurant') return 'Restaurant';
  if (tags.amenity === 'fast_food') return 'Fast Food';
  if (tags.amenity === 'food_court') return 'Food Court';
  if (tags.amenity === 'bar') return 'Bar';
  if (tags.amenity === 'pub') return 'Pub';
  if (tags.leisure === 'park') return 'Park';
  if (tags.leisure === 'garden') return 'Garden';
  if (tags.amenity === 'library') return 'Library';
  if (tags.tourism === 'museum') return 'Museum';
  if (tags.tourism === 'gallery') return 'Gallery';
  if (tags.shop) return `${tags.shop.charAt(0).toUpperCase() + tags.shop.slice(1)} Shop`;
  if (tags.amenity === 'cinema') return 'Cinema';
  return 'Place of Interest';
};

/**
 * Determine the type of POI based on its tags
 */
const getPoiType = (tags: any): string => {
  if (tags.amenity === 'cafe') return 'Cafe';
  if (tags.amenity === 'restaurant') return 'Restaurant';
  if (tags.amenity === 'fast_food') return 'Fast Food';
  if (tags.amenity === 'food_court') return 'Food Court';
  if (tags.amenity === 'bar') return 'Bar';
  if (tags.amenity === 'pub') return 'Pub';
  if (tags.leisure === 'park') return 'Park';
  if (tags.leisure === 'garden') return 'Garden';
  if (tags.amenity === 'library') return 'Library';
  if (tags.tourism === 'museum') return 'Museum';
  if (tags.tourism === 'gallery') return 'Gallery';
  if (tags.shop) return `Shop (${tags.shop})`;
  if (tags.amenity === 'cinema') return 'Cinema';
  if (tags.amenity) return `${tags.amenity.charAt(0).toUpperCase() + tags.amenity.slice(1)}`;
  if (tags.tourism) return `${tags.tourism.charAt(0).toUpperCase() + tags.tourism.slice(1)}`;
  if (tags.leisure) return `${tags.leisure.charAt(0).toUpperCase() + tags.leisure.slice(1)}`;
  return 'Place';
};

/**
 * Format address from OSM tags
 */
const formatPoiAddress = (tags: any): string => {
  const parts = [];
  
  // For Japanese addresses
  if (tags['addr:province']) parts.push(tags['addr:province']);
  if (tags['addr:city']) parts.push(tags['addr:city']);
  if (tags['addr:district']) parts.push(tags['addr:district']);
  if (tags['addr:quarter']) parts.push(tags['addr:quarter']);
  if (tags['addr:neighbourhood']) parts.push(tags['addr:neighbourhood']);
  if (tags['addr:block_number']) parts.push(tags['addr:block_number']);
  if (tags['addr:housenumber']) parts.push(tags['addr:housenumber']);
  
  // For international addresses
  if (parts.length === 0) {
    if (tags['addr:housenumber']) parts.push(tags['addr:housenumber']);
    if (tags['addr:street']) parts.push(tags['addr:street']);
    if (tags['addr:city']) parts.push(tags['addr:city']);
    if (tags['addr:postcode']) parts.push(tags['addr:postcode']);
  }
  
  return parts.join(', ');
}; 