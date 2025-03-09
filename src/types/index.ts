export interface LocationCoordinates {
  lat: number;
  lng: number;
}

export interface LocationAddress {
  name: string;
  displayName?: string;
  coordinates: LocationCoordinates;
}

export interface PointOfInterest {
  id: number;
  name: string;
  type: string;
  coordinates: LocationCoordinates;
  address?: string;
  distance?: number;
}

export interface SearchQuery {
  location1: LocationAddress;
  location2: LocationAddress;
  radius: number;
  categories: string[];
}

export type PoiCategory = 'cafe' | 'restaurant' | 'bar' | 'park' | 'library' | 'museum' | 'shop' | 'cinema';

export interface AppState {
  location1: LocationAddress | null;
  location2: LocationAddress | null;
  midpoint: LocationCoordinates | null;
  pointsOfInterest: PointOfInterest[];
  selectedPoi: PointOfInterest | null;
  isLoading: boolean;
  error: string | null;
} 