

import UIKit

import CoreLocation
import GoogleMaps
import MapKit
import SwiftyJSON

class ViewController: UIViewController,MKMapViewDelegate {
  
  fileprivate var places = [Place]()
  fileprivate let locationManager = CLLocationManager()
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var MaPView: GMSMapView!
  var arViewController: ARViewController!
  var startedLoadingPOIs = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.startUpdatingLocation()
    locationManager.requestWhenInUseAuthorization()
    mapView.userTrackingMode = MKUserTrackingMode.followWithHeading
    //DrawRoute()
    mapView.delegate = self
    DragDirection()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func showARController(_ sender: Any) {
    arViewController = ARViewController()
    arViewController.dataSource = self
    arViewController.maxDistance = 0
    arViewController.maxVisibleAnnotations = 30
    arViewController.maxVerticalLevel = 5
    arViewController.headingSmoothingFactor = 0.05
    
    arViewController.trackingManager.userDistanceFilter = 25
    arViewController.trackingManager.reloadDistanceFilter = 75
    arViewController.setAnnotations(places)
    arViewController.uiOptions.debugEnabled = false
    arViewController.uiOptions.closeButtonEnabled = true
    
    self.present(arViewController, animated: true, completion: nil)
  }
  
  func showInfoView(forPlace place: Place) {
    let alert = UIAlertController(title: place.placeName , message: place.infoText, preferredStyle: UIAlertControllerStyle.alert)
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
    arViewController.present(alert, animated: true, completion: nil)
  }
}

extension ViewController: CLLocationManagerDelegate {
  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    return true
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    
    if locations.count > 0 {
      let location = locations.last!
      if location.horizontalAccuracy < 100 {
        manager.stopUpdatingLocation()
        let span = MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
        let region = MKCoordinateRegion(center: location.coordinate, span: span)
        mapView.region = region
        
        if !startedLoadingPOIs {
          startedLoadingPOIs = true
          let loader = PlacesLoader()
          loader.loadPOIS(location: location, radius: 1000) { placesDict, error in
            if let dict = placesDict {
              guard let placesArray = dict.object(forKey: "results") as? [NSDictionary]  else { return }
              
              for placeDict in placesArray {
                let latitude = placeDict.value(forKeyPath: "geometry.location.lat") as! CLLocationDegrees
                let longitude = placeDict.value(forKeyPath: "geometry.location.lng") as! CLLocationDegrees
                let reference = placeDict.object(forKey: "reference") as! String
                let name = placeDict.object(forKey: "name") as! String
                let address = placeDict.object(forKey: "vicinity") as! String
                
                let location = CLLocation(latitude: latitude, longitude: longitude)
                let place = Place(location: location, reference: reference, name: name, address: address)
                
                self.places.append(place)
                let annotation = PlaceAnnotation(location: place.location!.coordinate, title: place.placeName)
                DispatchQueue.main.async {
                  self.mapView.addAnnotation(annotation)
                }
              }
            }
          }
        }
      }
    }
  }
  
  
  func DragDirection(){
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 40.7127, longitude: -74.0059), addressDictionary: nil))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.783333, longitude: -122.416667), addressDictionary: nil))
    request.requestsAlternateRoutes = true
    request.transportType = .automobile
    
    let directions = MKDirections(request: request)
    
    directions.calculate { [unowned self] response, error in
      guard let unwrappedResponse = response else { return }
      
      for route in unwrappedResponse.routes {
        self.mapView.add(route.polyline)
       // self.mapView.camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 40.7127, longitude: -74.0059), fromEyeCoordinate: CLLocationCoordinate2D(latitude: 37.783333, longitude: -122.416667), eyeAltitude:CLLocationDistance.ulpOfOne)
        self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
      }
    }
  }
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
    renderer.strokeColor = UIColor.blue
    renderer.lineWidth = 6
    return renderer
  }
  
  func DrawRoute(){
    
//    //  SVProgressHUD.show()
      guard let url = URL(string: "https://maps.googleapis.com/maps/api/directions/json?origin=33.6270752,73.065918&destination=33.6373732,73.0660971&mode=driving&key=****") else {return}
     let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
     guard let dataResponse = data,
      error == nil else {
        print(error?.localizedDescription ?? "Response Error")
        return }
    do{
      
      let jsonResponse = try JSONSerialization.jsonObject(with:
        dataResponse, options: [])
      print(jsonResponse)
      let json = JSON(jsonResponse)
      let routes = json["routes"].arrayValue
      var polyline = GMSPolyline()
        for route in routes
            {
                  let routeOverviewPolyline = route["overview_polyline"].dictionary
                  let points = routeOverviewPolyline?["points"]?.stringValue
                  let path = GMSPath.init(fromEncodedPath: points!)
                  polyline = GMSPolyline.init(path: path)
                  polyline.strokeColor = UIColor.gray
                  polyline.strokeWidth = 8
              polyline.map = self.MaPView
            }
      
//      self.mapView.add((route.polyline), level: MKOverlayLevel.aboveRoads)
//      let rect = route.polyline.boundingMapRect
//      self.mapView.setRegion(MKCoordinateRegionForMapRect(rect), animated: true)
     } catch let parsingError {
      print("Error", parsingError)
    }
  }
  task.resume()

//      let json = JSON(response.value ?? "")
//      let routes = json["routes"].arrayValue
//      print(routes.count)
//      for route in routes
//      {
//        let routeOverviewPolyline = route["overview_polyline"].dictionary
//        let points = routeOverviewPolyline?["points"]?.stringValue
//        let path = GMSPath.init(fromEncodedPath: points!)
//        self.polyline = GMSPolyline.init(path: path)
//        self.polyline.strokeColor = UIColor.gray
//        self.polyline.strokeWidth = 8
//        self.polyline.map = self.MapView
//      }
//      let position = CLLocationCoordinate2D(latitude: self.location.coordinate.latitude, longitude: self.location.coordinate.longitude)
//      let radius = (self.location).distance(from: self.Destination)
//      let update = GMSCameraUpdate.fit(coordinate: position, radius: radius)
//      self.MapView.animate(with: update)
  }
  
}

extension ViewController: ARDataSource {
  func ar(_ arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView {
    let annotationView = AnnotationView()
    annotationView.annotation = viewForAnnotation
    annotationView.delegate = self
    annotationView.frame = CGRect(x: 0, y: 0, width: 150, height: 50)
    
    return annotationView
  }
}

extension ViewController: AnnotationViewDelegate {
  func didTouch(annotationView: AnnotationView) {
    if let annotation = annotationView.annotation as? Place {
      let placesLoader = PlacesLoader()
      placesLoader.loadDetailInformation(forPlace: annotation) { resultDict, error in
        
        if let infoDict = resultDict?.object(forKey: "result") as? NSDictionary {
          annotation.phoneNumber = infoDict.object(forKey: "formatted_phone_number") as? String
          annotation.website = infoDict.object(forKey: "website") as? String
          
          self.showInfoView(forPlace: annotation)
        }
      }
      
    }
  }
}
