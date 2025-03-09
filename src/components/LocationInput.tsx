import React, { useState, useEffect, useRef } from 'react';
import { PoiCategory } from '../types';
import axios from 'axios';

interface LocationInputProps {
  onSearch: (location1: string, location2: string, radius: number, categories: PoiCategory[]) => void;
  isLoading: boolean;
}

interface Suggestion {
  place_id: number;
  display_name: string;
  name?: string;
}

const LocationInput: React.FC<LocationInputProps> = ({ onSearch, isLoading }) => {
  const [location1, setLocation1] = useState('');
  const [location2, setLocation2] = useState('');
  const [radius, setRadius] = useState(1);
  const [categories, setCategories] = useState<PoiCategory[]>(['cafe', 'restaurant', 'bar']);
  const [location1Suggestions, setLocation1Suggestions] = useState<Suggestion[]>([]);
  const [location2Suggestions, setLocation2Suggestions] = useState<Suggestion[]>([]);
  const [showSuggestions1, setShowSuggestions1] = useState(false);
  const [showSuggestions2, setShowSuggestions2] = useState(false);
  const [isTyping1, setIsTyping1] = useState(false);
  const [isTyping2, setIsTyping2] = useState(false);

  const suggestionRef1 = useRef<HTMLDivElement>(null);
  const suggestionRef2 = useRef<HTMLDivElement>(null);
  const inputRef1 = useRef<HTMLInputElement>(null);
  const inputRef2 = useRef<HTMLInputElement>(null);
  
  const availableCategories: { value: PoiCategory; label: string }[] = [
    { value: 'cafe', label: 'Cafes' },
    { value: 'restaurant', label: 'Restaurants' },
    { value: 'bar', label: 'Bars' },
    { value: 'park', label: 'Parks' },
    { value: 'library', label: 'Libraries' },
    { value: 'museum', label: 'Museums' },
    { value: 'shop', label: 'Shops' },
    { value: 'cinema', label: 'Cinemas' }
  ];

  // Handle outside click to close suggestions
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (suggestionRef1.current && !suggestionRef1.current.contains(event.target as Node) && 
          inputRef1.current && !inputRef1.current.contains(event.target as Node)) {
        setShowSuggestions1(false);
      }
      if (suggestionRef2.current && !suggestionRef2.current.contains(event.target as Node) && 
          inputRef2.current && !inputRef2.current.contains(event.target as Node)) {
        setShowSuggestions2(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Fetch location suggestions with debounce
  useEffect(() => {
    let debounceTimer: NodeJS.Timeout;
    
    if (location1 && location1.length > 2 && isTyping1) {
      debounceTimer = setTimeout(async () => {
        try {
          const response = await axios.get('https://nominatim.openstreetmap.org/search', {
            params: {
              q: location1,
              format: 'json',
              limit: 5,
            },
            headers: {
              'User-Agent': 'Halfway App (https://github.com/jimjatt1999/halfway)'
            }
          });
          
          setLocation1Suggestions(response.data);
          setShowSuggestions1(true);
          setIsTyping1(false);
        } catch (error) {
          console.error('Error fetching suggestions:', error);
        }
      }, 300);
    }
    
    return () => clearTimeout(debounceTimer);
  }, [location1, isTyping1]);

  // Fetch location suggestions with debounce for location 2
  useEffect(() => {
    let debounceTimer: NodeJS.Timeout;
    
    if (location2 && location2.length > 2 && isTyping2) {
      debounceTimer = setTimeout(async () => {
        try {
          const response = await axios.get('https://nominatim.openstreetmap.org/search', {
            params: {
              q: location2,
              format: 'json',
              limit: 5,
            },
            headers: {
              'User-Agent': 'Halfway App (https://github.com/jimjatt1999/halfway)'
            }
          });
          
          setLocation2Suggestions(response.data);
          setShowSuggestions2(true);
          setIsTyping2(false);
        } catch (error) {
          console.error('Error fetching suggestions:', error);
        }
      }, 300);
    }
    
    return () => clearTimeout(debounceTimer);
  }, [location2, isTyping2]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (location1 && location2) {
      onSearch(location1, location2, radius * 1000, categories);
    }
  };

  const handleCategoryChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value as PoiCategory;
    setCategories(prevCategories =>
      e.target.checked
        ? [...prevCategories, value]
        : prevCategories.filter(category => category !== value)
    );
  };

  const handleLocation1Change = (e: React.ChangeEvent<HTMLInputElement>) => {
    setLocation1(e.target.value);
    setIsTyping1(true);
  };

  const handleLocation2Change = (e: React.ChangeEvent<HTMLInputElement>) => {
    setLocation2(e.target.value);
    setIsTyping2(true);
  };

  const handleSuggestionClick = (suggestion: Suggestion, locationType: 'location1' | 'location2') => {
    if (locationType === 'location1') {
      setLocation1(suggestion.display_name);
      setShowSuggestions1(false);
    } else {
      setLocation2(suggestion.display_name);
      setShowSuggestions2(false);
    }
  };

  const formatSuggestion = (suggestion: Suggestion): string => {
    if (!suggestion.display_name) return '';
    
    // If the display name is too long, truncate it
    if (suggestion.display_name.length > 60) {
      return suggestion.display_name.substring(0, 60) + '...';
    }
    
    return suggestion.display_name;
  };

  return (
    <div className="location-input-container" style={{ 
      marginBottom: '30px', 
      backgroundColor: 'rgba(255, 255, 255, 0.95)',
      padding: '30px',
      borderRadius: '12px',
      boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
      backdropFilter: 'blur(10px)'
    }}>
      <form onSubmit={handleSubmit}>
        <div className="form-row" style={{ display: 'flex', gap: '20px', marginBottom: '25px' }}>
          <div className="form-group" style={{ flex: 1, position: 'relative' }}>
            <label htmlFor="location1" style={{ 
              display: 'block', 
              marginBottom: '10px', 
              fontWeight: '500', 
              color: '#333',
              fontSize: '15px'
            }}>
              Your Location
            </label>
            <input
              id="location1"
              ref={inputRef1}
              type="text"
              value={location1}
              onChange={handleLocation1Change}
              onFocus={() => location1.length > 2 && setShowSuggestions1(true)}
              placeholder="Enter city, neighborhood, or address"
              required
              style={{
                width: '100%',
                padding: '12px 16px',
                border: '1px solid #e1e1e1',
                borderRadius: '8px',
                fontSize: '16px',
                transition: 'all 0.2s ease',
                boxShadow: '0 1px 3px rgba(0, 0, 0, 0.05) inset',
                outline: 'none'
              }}
            />
            {showSuggestions1 && location1Suggestions.length > 0 && (
              <div 
                ref={suggestionRef1}
                style={{
                  position: 'absolute',
                  top: '100%',
                  left: 0,
                  right: 0,
                  backgroundColor: 'white',
                  borderRadius: '8px',
                  boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)',
                  zIndex: 10,
                  maxHeight: '200px',
                  overflowY: 'auto',
                  marginTop: '5px'
                }}
              >
                {location1Suggestions.map((suggestion) => (
                  <div
                    key={suggestion.place_id}
                    onClick={() => handleSuggestionClick(suggestion, 'location1')}
                    style={{
                      padding: '12px 16px',
                      cursor: 'pointer',
                      borderBottom: '1px solid #f0f0f0',
                      transition: 'background-color 0.2s ease',
                      fontSize: '14px'
                    }}
                    onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#f9f9f9'}
                    onMouseOut={(e) => e.currentTarget.style.backgroundColor = 'white'}
                  >
                    {formatSuggestion(suggestion)}
                  </div>
                ))}
              </div>
            )}
          </div>
          <div className="form-group" style={{ flex: 1, position: 'relative' }}>
            <label htmlFor="location2" style={{ 
              display: 'block', 
              marginBottom: '10px', 
              fontWeight: '500', 
              color: '#333',
              fontSize: '15px'
            }}>
              Friend's Location
            </label>
            <input
              id="location2"
              ref={inputRef2}
              type="text"
              value={location2}
              onChange={handleLocation2Change}
              onFocus={() => location2.length > 2 && setShowSuggestions2(true)}
              placeholder="Enter city, neighborhood, or address"
              required
              style={{
                width: '100%',
                padding: '12px 16px',
                border: '1px solid #e1e1e1',
                borderRadius: '8px',
                fontSize: '16px',
                transition: 'all 0.2s ease',
                boxShadow: '0 1px 3px rgba(0, 0, 0, 0.05) inset',
                outline: 'none'
              }}
            />
            {showSuggestions2 && location2Suggestions.length > 0 && (
              <div 
                ref={suggestionRef2}
                style={{
                  position: 'absolute',
                  top: '100%',
                  left: 0,
                  right: 0,
                  backgroundColor: 'white',
                  borderRadius: '8px',
                  boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)',
                  zIndex: 10,
                  maxHeight: '200px',
                  overflowY: 'auto',
                  marginTop: '5px'
                }}
              >
                {location2Suggestions.map((suggestion) => (
                  <div
                    key={suggestion.place_id}
                    onClick={() => handleSuggestionClick(suggestion, 'location2')}
                    style={{
                      padding: '12px 16px',
                      cursor: 'pointer',
                      borderBottom: '1px solid #f0f0f0',
                      transition: 'background-color 0.2s ease',
                      fontSize: '14px'
                    }}
                    onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#f9f9f9'}
                    onMouseOut={(e) => e.currentTarget.style.backgroundColor = 'white'}
                  >
                    {formatSuggestion(suggestion)}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="form-row" style={{ 
          display: 'flex', 
          alignItems: 'center', 
          gap: '30px', 
          marginBottom: '25px',
          flexWrap: 'wrap'
        }}>
          <div className="form-group" style={{ flex: '1 1 250px' }}>
            <label htmlFor="radius" style={{ 
              display: 'block', 
              marginBottom: '10px', 
              fontWeight: '500', 
              color: '#333',
              fontSize: '15px'
            }}>
              Search Radius (km): <span style={{ fontWeight: 'bold' }}>{radius}</span>
            </label>
            <div style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '10px' 
            }}>
              <span style={{ fontSize: '13px', color: '#666' }}>0.5</span>
              <input
                id="radius"
                type="range"
                min="0.5"
                max="5"
                step="0.5"
                value={radius}
                onChange={(e) => setRadius(parseFloat(e.target.value))}
                style={{ 
                  width: '100%',
                  accentColor: '#2979FF',
                  height: '6px'
                }}
              />
              <span style={{ fontSize: '13px', color: '#666' }}>5</span>
            </div>
          </div>
          
          <div className="form-group" style={{ flex: '1 1 350px' }}>
            <label style={{ 
              display: 'block', 
              marginBottom: '10px', 
              fontWeight: '500', 
              color: '#333',
              fontSize: '15px'
            }}>
              Places to find:
            </label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px' }}>
              {availableCategories.map(category => (
                <div key={category.value} style={{ 
                  display: 'flex', 
                  alignItems: 'center',
                }}>
                  <label htmlFor={`category-${category.value}`} style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '6px 12px',
                    borderRadius: '20px',
                    backgroundColor: categories.includes(category.value) ? '#e1efff' : '#f5f5f7',
                    border: `1px solid ${categories.includes(category.value) ? '#2979FF' : '#e1e1e1'}`,
                    cursor: 'pointer',
                    fontSize: '14px',
                    color: categories.includes(category.value) ? '#2979FF' : '#666',
                    transition: 'all 0.2s ease',
                    fontWeight: categories.includes(category.value) ? '500' : 'normal',
                  }}>
                    <input
                      type="checkbox"
                      id={`category-${category.value}`}
                      value={category.value}
                      checked={categories.includes(category.value)}
                      onChange={handleCategoryChange}
                      style={{ 
                        position: 'absolute',
                        opacity: 0,
                        cursor: 'pointer'
                      }}
                    />
                    {category.label}
                  </label>
                </div>
              ))}
            </div>
          </div>
        </div>

        <button 
          type="submit" 
          disabled={!location1 || !location2 || isLoading || categories.length === 0}
          style={{
            background: 'linear-gradient(135deg, #2979FF, #1D68E3)',
            color: 'white',
            border: 'none',
            padding: '14px 28px',
            borderRadius: '30px',
            fontSize: '16px',
            cursor: 'pointer',
            opacity: (!location1 || !location2 || isLoading || categories.length === 0) ? 0.7 : 1,
            boxShadow: '0 4px 12px rgba(41, 121, 255, 0.3)',
            transition: 'all 0.2s ease',
            fontWeight: '500',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px'
          }}
          onMouseOver={(e) => {
            if (!(!location1 || !location2 || isLoading || categories.length === 0)) {
              e.currentTarget.style.transform = 'translateY(-2px)';
              e.currentTarget.style.boxShadow = '0 6px 16px rgba(41, 121, 255, 0.4)';
            }
          }}
          onMouseOut={(e) => {
            e.currentTarget.style.transform = 'translateY(0)';
            e.currentTarget.style.boxShadow = '0 4px 12px rgba(41, 121, 255, 0.3)';
          }}
        >
          {isLoading ? (
            <>
              <span className="loading-spinner" style={{
                display: 'inline-block',
                width: '16px',
                height: '16px',
                border: '2px solid rgba(255,255,255,0.3)',
                borderRadius: '50%',
                borderTopColor: 'white',
                animation: 'spin 0.8s linear infinite'
              }}></span>
              Searching...
            </>
          ) : (
            'Find Halfway Places'
          )}
        </button>
      </form>
    </div>
  );
};

export default LocationInput; 