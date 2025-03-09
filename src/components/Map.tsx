import React, { useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Circle, useMap, Polyline } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { LocationCoordinates, LocationAddress, PointOfInterest } from '../types';

// Fix for Leaflet marker icons
import icon from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

let DefaultIcon = L.icon({
  iconUrl: icon,
  shadowUrl: iconShadow,
  iconSize: [25, 41],
  iconAnchor: [12, 41]
});

L.Marker.prototype.options.icon = DefaultIcon;

// Custom icons for different markers
const createCustomIcon = (color: string) => {
  return L.divIcon({
    className: 'custom-marker',
    html: `<div style="
      background-color: ${color}; 
      width: 28px; 
      height: 28px; 
      border-radius: 50%; 
      border: 3px solid white;
      box-shadow: 0 2px 5px rgba(0, 0, 0, 0.2);
      display: flex;
      align-items: center;
      justify-content: center;
    "></div>`,
    iconSize: [28, 28],
    iconAnchor: [14, 14]
  });
};

const locationIcon = createCustomIcon('#2979FF');
const midpointIcon = createCustomIcon('#FF5733');
const poiIcon = createCustomIcon('#4CAF50');
const selectedPoiIcon = createCustomIcon('#FFC107');

interface MapCenterProps {
  center: LocationCoordinates;
  zoom: number;
}

// Component to handle map re-centering
const MapCenter: React.FC<MapCenterProps> = ({ center, zoom }) => {
  const map = useMap();
  useEffect(() => {
    map.setView([center.lat, center.lng], zoom);
  }, [center, map, zoom]);
  return null;
};

interface MapProps {
  location1: LocationAddress | null;
  location2: LocationAddress | null;
  midpoint: LocationCoordinates | null;
  pointsOfInterest: PointOfInterest[];
  selectedPoi: PointOfInterest | null;
  onSelectPoi: (poi: PointOfInterest | null) => void;
  searchRadius: number;
}

const Map: React.FC<MapProps> = ({
  location1,
  location2,
  midpoint,
  pointsOfInterest,
  selectedPoi,
  onSelectPoi,
  searchRadius
}) => {
  // Default center (London) and zoom
  const defaultCenter: LocationCoordinates = { lat: 51.505, lng: -0.09 };
  const defaultZoom = 13;

  // Center map on midpoint if available, otherwise on default center
  const center = midpoint || defaultCenter;
  const zoom = midpoint ? 14 : defaultZoom;

  return (
    <MapContainer
      center={[center.lat, center.lng]} 
      zoom={zoom} 
      style={{ 
        height: '100%', 
        width: '100%', 
        borderRadius: '12px',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.1)'
      }}
      zoomControl={false}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      
      <MapCenter center={center} zoom={zoom} />
      
      {/* Controls */}
      <div 
        className="leaflet-control leaflet-bar" 
        style={{ 
          position: 'absolute', 
          top: '10px', 
          right: '10px',
          zIndex: 1000,
          backgroundColor: 'white',
          borderRadius: '8px',
          boxShadow: '0 2px 8px rgba(0, 0, 0, 0.15)'
        }}
      >
        <div 
          onClick={() => onSelectPoi(null)}
          style={{ 
            width: '40px', 
            height: '40px', 
            display: 'flex', 
            alignItems: 'center', 
            justifyContent: 'center',
            cursor: 'pointer'
          }}
          title="Reset Selection"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12C22 17.5228 17.5228 22 12 22ZM12 20C16.4183 20 20 16.4183 20 12C20 7.58172 16.4183 4 12 4C7.58172 4 4 7.58172 4 12C4 16.4183 7.58172 20 12 20ZM12 10.5858L14.8284 7.75736L16.2426 9.17157L13.4142 12L16.2426 14.8284L14.8284 16.2426L12 13.4142L9.17157 16.2426L7.75736 14.8284L10.5858 12L7.75736 9.17157L9.17157 7.75736L12 10.5858Z" fill="#666666"/>
          </svg>
        </div>
      </div>
      
      {/* Render location1 marker */}
      {location1 && (
        <Marker 
          position={[location1.coordinates.lat, location1.coordinates.lng]} 
          icon={locationIcon}
        >
          <Popup
            className="custom-popup"
            closeButton={false}
            autoClose={false}
            minWidth={220}
            maxWidth={300}
          >
            <div>
              <h3 style={{ 
                fontSize: '16px', 
                margin: '0 0 8px 0',
                fontWeight: '600',
                color: '#333'
              }}>Starting Point</h3>
              <p style={{ margin: '0', fontSize: '14px', color: '#666' }}>
                {location1.displayName || location1.name}
              </p>
            </div>
          </Popup>
        </Marker>
      )}
      
      {/* Render location2 marker */}
      {location2 && (
        <Marker 
          position={[location2.coordinates.lat, location2.coordinates.lng]} 
          icon={locationIcon}
        >
          <Popup
            className="custom-popup"
            closeButton={false}
            autoClose={false}
            minWidth={220}
            maxWidth={300}
          >
            <div>
              <h3 style={{ 
                fontSize: '16px', 
                margin: '0 0 8px 0',
                fontWeight: '600',
                color: '#333'
              }}>Destination Point</h3>
              <p style={{ margin: '0', fontSize: '14px', color: '#666' }}>
                {location2.displayName || location2.name}
              </p>
            </div>
          </Popup>
        </Marker>
      )}
      
      {/* Render midpoint marker and search radius */}
      {midpoint && (
        <>
          <Marker 
            position={[midpoint.lat, midpoint.lng]} 
            icon={midpointIcon}
          >
            <Popup
              className="custom-popup"
              closeButton={false}
              autoClose={false}
              minWidth={220}
              maxWidth={300}
            >
              <div>
                <h3 style={{ 
                  fontSize: '16px', 
                  margin: '0 0 8px 0',
                  fontWeight: '600',
                  color: '#FF5733'
                }}>Midpoint</h3>
                <p style={{ margin: '0', fontSize: '14px', color: '#666' }}>
                  This is the halfway point between your two locations
                </p>
                <div style={{ 
                  fontSize: '12px', 
                  marginTop: '8px',
                  color: '#888',
                  backgroundColor: '#f9f9f9',
                  padding: '4px 8px',
                  borderRadius: '4px'
                }}>
                  {midpoint.lat.toFixed(6)}, {midpoint.lng.toFixed(6)}
                </div>
              </div>
            </Popup>
          </Marker>
          
          <Circle 
            center={[midpoint.lat, midpoint.lng]} 
            radius={searchRadius} 
            pathOptions={{ 
              color: '#FF5733', 
              fillColor: '#FF5733', 
              fillOpacity: 0.1, 
              weight: 2, 
              dashArray: '5, 5'
            }}
          />
        </>
      )}
      
      {/* Render POI markers */}
      {pointsOfInterest.map(poi => (
        <Marker 
          key={poi.id} 
          position={[poi.coordinates.lat, poi.coordinates.lng]} 
          icon={selectedPoi && selectedPoi.id === poi.id ? selectedPoiIcon : poiIcon}
          eventHandlers={{
            click: () => onSelectPoi(poi)
          }}
        >
          <Popup
            className="custom-popup"
            closeButton={false}
            autoClose={false}
            minWidth={220}
            maxWidth={300}
          >
            <div>
              <h3 style={{ 
                fontSize: '16px', 
                margin: '0 0 4px 0',
                fontWeight: '600',
                color: selectedPoi && selectedPoi.id === poi.id ? '#FFC107' : '#4CAF50'
              }}>{poi.name}</h3>
              <p style={{ 
                margin: '0 0 8px 0', 
                fontSize: '14px', 
                color: '#666', 
                fontWeight: '500'
              }}>{poi.type}</p>
              {poi.address && (
                <p style={{ 
                  margin: '0 0 8px 0', 
                  fontSize: '13px', 
                  color: '#777',
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: '5px'
                }}>
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ marginTop: '2px', flexShrink: 0 }}>
                    <path d="M12 20.8995L16.9497 15.9497C19.6834 13.2161 19.6834 8.78392 16.9497 6.05025C14.2161 3.31658 9.78392 3.31658 7.05025 6.05025C4.31658 8.78392 4.31658 13.2161 7.05025 15.9497L12 20.8995Z" fill="#999999"/>
                  </svg>
                  <span>{poi.address}</span>
                </p>
              )}
              {poi.distance && (
                <div style={{ 
                  fontSize: '13px', 
                  color: '#777',
                  marginTop: '8px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '5px',
                  backgroundColor: '#f5f5f7',
                  padding: '4px 8px',
                  borderRadius: '12px',
                  width: 'fit-content'
                }}>
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M17.6 11.5999C17.6 14.3415 16.0215 16.8373 13.7193 18.3182C13.0835 18.7376 12.5837 19.0273 12.2602 19.1994C12.0994 19.2851 11.9806 19.3427 11.9105 19.3779C11.8754 19.3955 11.8485 19.4087 11.8307 19.4177L11.8092 19.4287L11.8027 19.432L11.8005 19.4332C11.8003 19.4333 11.8 19.4334 12 20.1999C12.2 19.4334 12.1997 19.4333 12.1995 19.4332L12.1973 19.432L12.1908 19.4287L12.1693 19.4177C12.1515 19.4087 12.1246 19.3955 12.0895 19.3779C12.0194 19.3427 11.9006 19.2851 11.7398 19.1994C11.4163 19.0273 10.9165 18.7376 10.2807 18.3182C7.97848 16.8373 6.39999 14.3415 6.39999 11.5999C6.39999 7.4623 9.70036 4.1999 12 4.1999C14.2996 4.1999 17.6 7.4623 17.6 11.5999Z" fill="#999999"/>
                  </svg>
                  <span>{poi.distance.toFixed(2)} km from midpoint</span>
                </div>
              )}
              <button 
                onClick={() => onSelectPoi(poi)}
                style={{
                  display: 'block',
                  width: '100%',
                  padding: '6px 0',
                  backgroundColor: selectedPoi && selectedPoi.id === poi.id ? '#FFC107' : '#4CAF50',
                  color: 'white',
                  border: 'none',
                  borderRadius: '4px',
                  fontSize: '13px',
                  fontWeight: '500',
                  cursor: 'pointer',
                  marginTop: '10px',
                  textAlign: 'center'
                }}
              >
                {selectedPoi && selectedPoi.id === poi.id ? 'Selected' : 'Select This Place'}
              </button>
            </div>
          </Popup>
        </Marker>
      ))}
      
      {/* Render a line between the two locations */}
      {location1 && location2 && (
        <Polyline 
          positions={[
            [location1.coordinates.lat, location1.coordinates.lng],
            [location2.coordinates.lat, location2.coordinates.lng]
          ]}
          pathOptions={{ 
            color: '#2979FF', 
            weight: 3, 
            opacity: 0.6,
            dashArray: '10, 10'
          }}
        />
      )}
    </MapContainer>
  );
};

export default Map; 