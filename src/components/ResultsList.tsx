import React from 'react';
import { PointOfInterest } from '../types';

interface ResultsListProps {
  pointsOfInterest: PointOfInterest[];
  selectedPoi: PointOfInterest | null;
  onSelectPoi: (poi: PointOfInterest | null) => void;
}

const ResultsList: React.FC<ResultsListProps> = ({ 
  pointsOfInterest, 
  selectedPoi, 
  onSelectPoi 
}) => {
  if (pointsOfInterest.length === 0) {
    return null;
  }

  // Get category icons
  const getCategoryIcon = (type: string): React.ReactNode => {
    const iconColor = '#2979FF';
    
    if (type.includes('Cafe')) {
      return (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M2 21V19H20V21H2ZM4 17V13C4 10.2386 6.23858 8 9 8H15C17.7614 8 20 10.2386 20 13V17H4ZM20 7H9V3H20V7Z" fill={iconColor}/>
        </svg>
      );
    }
    
    if (type.includes('Restaurant')) {
      return (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M4.99983 2V11.5C4.99983 12.33 5.66983 13 6.49983 13H7.99983V22H9.99983V2H7.99983V11H6.99983V2H4.99983ZM15.4998 8V13.61C16.2598 13.86 16.9998 14.36 17.4998 15.06C17.9998 15.76 18.2498 16.57 18.2498 17.45C18.2498 18.71 17.7898 19.84 16.9998 20.62C16.2098 21.41 15.0798 21.87 13.8198 21.87C12.5598 21.87 11.4298 21.41 10.6398 20.62C9.84983 19.84 9.37983 18.71 9.37983 17.45C9.37983 16.57 9.62983 15.76 10.1298 15.06C10.6298 14.36 11.3598 13.86 12.1298 13.61V8C12.1298 6.9 12.9998 6 14.0598 6H15.9998C17.0998 6 17.9998 6.9 17.9998 8V13H15.4998V8Z" fill={iconColor}/>
        </svg>
      );
    }
    
    if (type.includes('Bar')) {
      return (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M21 3V5C21 9.9 16.5 12 16.5 12L17 22H7L7.5 12C7.5 12 3 9.9 3 5V3H21ZM5 5V4H19V5C19 6.5 18 8 16.5 9.5C15 11 14 12 14 12H10C10 12 9 11 7.5 9.5C6 8 5 6.5 5 5Z" fill={iconColor}/>
        </svg>
      );
    }
    
    if (type.includes('Park')) {
      return (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M13.2 8C13.1 8.7 13.1 9.3 13.2 10H10.8C10.9 9.3 10.9 8.7 10.8 8H13.2ZM20 8C20.6 8 21 8.4 21 9V10C21 10.6 20.6 11 20 11H19.9C19.7 12.7 19 14.4 18 16C18.9 16.7 19.5 17.8 19.7 19H4.3C4.5 17.8 5.1 16.7 6 16C5 14.4 4.3 12.7 4.1 11H4C3.4 11 3 10.6 3 10V9C3 8.4 3.4 8 4 8H7.8C8.3 6.5 9.1 5.2 10.2 4.2C11.3 3.2 12.6 2.7 14 2.7C15.4 2.7 16.7 3.2 17.8 4.2C18.9 5.2 19.7 6.5 20.2 8Z" fill={iconColor}/>
        </svg>
      );
    }
    
    if (type.includes('Library')) {
      return (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 3L2 8L12 13L22 8L12 3ZM2 12L12 17L22 12V16L12 21L2 16V12Z" fill={iconColor}/>
        </svg>
      );
    }
    
    if (type.includes('Museum')) {
      return (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M2 20H22V22H2V20ZM4 17H20V19H4V17ZM3 11H21V15H3V11ZM11.121 2.46L12 2L21 7H3L11.121 2.46Z" fill={iconColor}/>
        </svg>
      );
    }
    
    if (type.includes('Shop')) {
      return (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 13C10.9 13 10 13.9 10 15C10 16.1 10.9 17 12 17C13.1 17 14 16.1 14 15C14 13.9 13.1 13 12 13ZM18 3H6C4.9 3 4 3.9 4 5V19C4 20.1 4.9 21 6 21H18C19.1 21 20 20.1 20 19V5C20 3.9 19.1 3 18 3ZM18 19H6V16H8.03C8.28 17.19 9.53 18 11 18H13C14.47 18 15.72 17.19 15.97 16H18V19ZM18 14H6V5H18V14Z" fill={iconColor}/>
        </svg>
      );
    }
    
    if (type.includes('Cinema')) {
      return (
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M18 3V5H16V3H18ZM8 3V5H6V3H8ZM21 3C21.552 3 22 3.448 22 4V20C22 20.552 21.552 21 21 21H3C2.448 21 2 20.552 2 20V4C2 3.448 2.448 3 3 3H21ZM20 5H4V19H20V5ZM12 15C13.657 15 15 13.657 15 12C15 10.343 13.657 9 12 9C10.343 9 9 10.343 9 12C9 13.657 10.343 15 12 15Z" fill={iconColor}/>
        </svg>
      );
    }
    
    // Default icon for other categories
    return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 12C14.2091 12 16 10.2091 16 8C16 5.79086 14.2091 4 12 4C9.79086 4 8 5.79086 8 8C8 10.2091 9.79086 12 12 12ZM12 14C8.13401 14 5 17.134 5 21H19C19 17.134 15.866 14 12 14Z" fill={iconColor}/>
      </svg>
    );
  };

  return (
    <div className="results-container" style={{ 
      backgroundColor: 'rgba(255, 255, 255, 0.95)',
      padding: '30px',
      borderRadius: '12px',
      boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
      backdropFilter: 'blur(10px)',
      height: '100%',
      display: 'flex',
      flexDirection: 'column'
    }}>
      <h2 style={{ 
        marginBottom: '20px', 
        marginTop: '0',
        fontSize: '22px',
        fontWeight: '600',
        color: '#333',
        display: 'flex',
        alignItems: 'center',
        gap: '10px'
      }}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M15 4.5L17.5 7L13 11.5L9 7.5L2 14.5L3.5 16L9 10.5L13 14.5L19 8.5L21.5 11V4.5H15Z" fill="#2979FF"/>
        </svg>
        Places Halfway Between You
        <span style={{ 
          marginLeft: 'auto',
          fontSize: '14px', 
          fontWeight: 'normal',
          color: '#666',
          backgroundColor: '#f5f5f7',
          borderRadius: '20px',
          padding: '3px 10px'
        }}>
          {pointsOfInterest.length} found
        </span>
      </h2>
      
      <div className="results-list" style={{ 
        display: 'flex',
        flexDirection: 'column',
        gap: '12px',
        overflowY: 'auto',
        flex: 1,
        paddingRight: '5px'
      }}>
        {pointsOfInterest.map(poi => (
          <div 
            key={poi.id} 
            className={`result-card ${selectedPoi && selectedPoi.id === poi.id ? 'selected' : ''}`}
            style={{
              padding: '16px',
              borderRadius: '12px',
              cursor: 'pointer',
              backgroundColor: selectedPoi && selectedPoi.id === poi.id ? '#e3f2fd' : 'white',
              border: selectedPoi && selectedPoi.id === poi.id ? '1px solid #2979FF' : '1px solid #eaeaea',
              transition: 'all 0.2s ease',
              boxShadow: selectedPoi && selectedPoi.id === poi.id 
                ? '0 4px 12px rgba(41, 121, 255, 0.15)' 
                : '0 2px 6px rgba(0, 0, 0, 0.04)',
              display: 'flex',
              flexDirection: 'column',
              gap: '6px'
            }}
            onClick={() => onSelectPoi(poi)}
            onMouseOver={(e) => {
              if (!(selectedPoi && selectedPoi.id === poi.id)) {
                e.currentTarget.style.borderColor = '#c7deff';
                e.currentTarget.style.backgroundColor = '#f9fbff';
                e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.08)';
              }
            }}
            onMouseOut={(e) => {
              if (!(selectedPoi && selectedPoi.id === poi.id)) {
                e.currentTarget.style.borderColor = '#eaeaea';
                e.currentTarget.style.backgroundColor = 'white';
                e.currentTarget.style.boxShadow = '0 2px 6px rgba(0, 0, 0, 0.04)';
              }
            }}
          >
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: '10px' }}>
              <div style={{ 
                padding: '8px',
                backgroundColor: selectedPoi && selectedPoi.id === poi.id ? '#c7deff' : '#f0f5ff',
                borderRadius: '8px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginTop: '2px'
              }}>
                {getCategoryIcon(poi.type)}
              </div>
              
              <div style={{ flex: 1 }}>
                <h3 style={{ 
                  margin: '0 0 4px 0', 
                  fontSize: '17px', 
                  fontWeight: '600',
                  color: selectedPoi && selectedPoi.id === poi.id ? '#2979FF' : '#333',
                  lineHeight: 1.3
                }}>{poi.name}</h3>
                
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: '8px',
                  flexWrap: 'wrap'
                }}>
                  <span style={{ 
                    color: '#666', 
                    fontSize: '14px',
                    fontWeight: '500'
                  }}>
                    {poi.type}
                  </span>
                  
                  {poi.distance && (
                    <>
                      <span style={{ color: '#ccc', fontSize: '14px' }}>•</span>
                      <div style={{ 
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px',
                        fontSize: '14px',
                        color: '#666'
                      }}>
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M17.6 11.5999C17.6 14.3415 16.0215 16.8373 13.7193 18.3182C13.0835 18.7376 12.5837 19.0273 12.2602 19.1994C12.0994 19.2851 11.9806 19.3427 11.9105 19.3779C11.8754 19.3955 11.8485 19.4087 11.8307 19.4177L11.8092 19.4287L11.8027 19.432L11.8005 19.4332C11.8003 19.4333 11.8 19.4334 12 20.1999C12.2 19.4334 12.1997 19.4333 12.1995 19.4332L12.1973 19.432L12.1908 19.4287L12.1693 19.4177C12.1515 19.4087 12.1246 19.3955 12.0895 19.3779C12.0194 19.3427 11.9006 19.2851 11.7398 19.1994C11.4163 19.0273 10.9165 18.7376 10.2807 18.3182C7.97848 16.8373 6.39999 14.3415 6.39999 11.5999C6.39999 7.4623 9.70036 4.1999 12 4.1999C14.2996 4.1999 17.6 7.4623 17.6 11.5999ZM12 13.1999C12.8837 13.1999 13.6 12.4836 13.6 11.5999C13.6 10.7162 12.8837 9.9999 12 9.9999C11.1163 9.9999 10.4 10.7162 10.4 11.5999C10.4 12.4836 11.1163 13.1999 12 13.1999Z" fill="#666666"/>
                        </svg>
                        {poi.distance.toFixed(2)} km
                      </div>
                    </>
                  )}
                </div>
              </div>
              
              {selectedPoi && selectedPoi.id === poi.id && (
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12C22 17.5228 17.5228 22 12 22ZM12 20C16.4183 20 20 16.4183 20 12C20 7.58172 16.4183 4 12 4C7.58172 4 4 7.58172 4 12C4 16.4183 7.58172 20 12 20ZM11.0026 16L6.75999 11.7574L8.17421 10.3431L11.0026 13.1716L16.6595 7.51472L18.0737 8.92893L11.0026 16Z" fill="#2979FF"/>
                </svg>
              )}
            </div>
            
            {poi.address && (
              <div style={{ 
                fontSize: '14px', 
                color: '#777',
                marginTop: '2px',
                display: 'flex',
                alignItems: 'flex-start',
                gap: '10px'
              }}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ marginTop: '2px', flexShrink: 0 }}>
                  <path d="M12 20.8995L16.9497 15.9497C19.6834 13.2161 19.6834 8.78392 16.9497 6.05025C14.2161 3.31658 9.78392 3.31658 7.05025 6.05025C4.31658 8.78392 4.31658 13.2161 7.05025 15.9497L12 20.8995ZM12 23.7279L5.63604 17.364C2.12132 13.8492 2.12132 8.15076 5.63604 4.63604C9.15076 1.12132 14.8492 1.12132 18.364 4.63604C21.8787 8.15076 21.8787 13.8492 18.364 17.364L12 23.7279ZM12 13C13.1046 13 14 12.1046 14 11C14 9.89543 13.1046 9 12 9C10.8954 9 10 9.89543 10 11C10 12.1046 10.8954 13 12 13ZM12 15C9.79086 15 8 13.2091 8 11C8 8.79086 9.79086 7 12 7C14.2091 7 16 8.79086 16 11C16 13.2091 14.2091 15 12 15Z" fill="#777777"/>
                </svg>
                {poi.address}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default ResultsList; 