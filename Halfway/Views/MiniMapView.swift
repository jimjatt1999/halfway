import SwiftUI
import MapKit

struct MiniMapView: UIViewRepresentable {
    var location1: Location?
    var location2: Location?
    var midpoint: CLLocationCoordinate2D?
    var searchRadius: Double
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Clear existing annotations and overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Add annotations for location1 and location2
        var annotationsToShow: [MKAnnotation] = []
        
        if let location1 = location1 {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location1.coordinate
            annotation.title = "Location 1"
            mapView.addAnnotation(annotation)
            annotationsToShow.append(annotation)
        }
        
        if let location2 = location2 {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location2.coordinate
            annotation.title = "Location 2"
            mapView.addAnnotation(annotation)
            annotationsToShow.append(annotation)
        }
        
        // Add midpoint and circle overlay
        if let midpoint = midpoint {
            let annotation = MKPointAnnotation()
            annotation.coordinate = midpoint
            annotation.title = "Midpoint"
            mapView.addAnnotation(annotation)
            annotationsToShow.append(annotation)
            
            // Add circle overlay for search radius
            let circle = MKCircle(center: midpoint, radius: searchRadius * 1000)
            mapView.addOverlay(circle)
            
            // Calculate region to show all points
            if !annotationsToShow.isEmpty {
                mapView.showAnnotations(annotationsToShow, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MiniMapView
        
        init(_ parent: MiniMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "MiniMapPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            if let title = annotation.title {
                if title == "Location 1" {
                    (annotationView as? MKMarkerAnnotationView)?.markerTintColor = .blue
                } else if title == "Location 2" {
                    (annotationView as? MKMarkerAnnotationView)?.markerTintColor = .green
                } else if title == "Midpoint" {
                    (annotationView as? MKMarkerAnnotationView)?.markerTintColor = .red
                }
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 1.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
} 