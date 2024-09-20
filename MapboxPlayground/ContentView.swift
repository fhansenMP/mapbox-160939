//
//  ContentView.swift
//  MapboxPlayground
//
//  Created by Frederik Hansen on 27/02/2024.
//
 //  ContentView.swift
 //  MapboxPlayground
 //
 //  Created by Frederik Hansen on 27/02/2024.
 //

 import SwiftUI
 @_spi(Experimental) import MapboxMaps

 struct ContentView: View {
     var body: some View {
         MapBoxMapView()
     }
 }

 #Preview {
     ContentView()
 }

 struct MapBoxMapView: UIViewControllerRepresentable {
     
     func makeUIViewController(context: Context) -> MapViewController {
         return MapViewController()
     }
       
     func updateUIViewController(_ uiViewController: MapViewController, context: Context) { }
     
 }

 class MapViewController: UIViewController {
     
     private var mapView: MapView?
     
     private var observer: Cancelable?
     
     override public func viewDidLoad() {
         super.viewDidLoad()
         let cameraOptions = CameraOptions(
                     center: Constants.aalborgOffice.coordinates,
                     zoom: 17,
                     pitch: 0
                 )
         let options = MapInitOptions(cameraOptions: cameraOptions)
         
         mapView = MapView(frame: view.bounds, mapInitOptions: options)
         mapView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
         if let view = mapView {
             self.view.addSubview(view)
         }

         guard let mapboxMap = mapView?.mapboxMap else {
             return
         }
         
         for _ in 0...100 {
             let randomLat = Double.random(in: Constants.boxNorthWest.latitude...Constants.boxSouthEast.latitude)
             let randomLng = Double.random(in: Constants.boxNorthWest.longitude...Constants.boxSouthEast.longitude)
             Constants.locationsSet.append(CLLocationCoordinate2D(latitude: randomLat, longitude: randomLng))
         }

         mapboxMap.loadStyle(.standard) { _ in
             
             Task.detached {
                 if let url = URL(string: "https://play-lh.googleusercontent.com/gkfKxfeENcbSoi79Vp93JquMW7kRRVS5wbLa5vDhNmIM3Rnbj5upeTNimeqetlv7HA=s64-rw"),
                    let data = try? Data(contentsOf: url),
                    let icon = UIImage(data: data) {
                     Task { @MainActor in
                         try mapboxMap.addImage(icon, id: Constants.iconId)
                     }
                 }
             }
                          
             var layer = SymbolLayer(id: "symbol-layer", source: Constants.sourceId)
             layer.iconImage = .constant(.name(Constants.iconId))
             layer.symbolZElevate = .constant(true)
             layer.symbolSortKey = .expression(Exp(.get) { "sortkey" })
             layer.iconAllowOverlap = .constant(true)
             layer.slot = .middle
             
             let source = GeoJSONSource(id: Constants.sourceId)
             try! mapboxMap.addSource(source)
             try! mapboxMap.addLayer(layer)

             self.observer = mapboxMap.onCameraChanged.observe { _ in
                 Task {
                     await self.update()
                 }
             }

             Task {
                 await self.update()
             }
             
         }
         
     }
     
     @MainActor
     func update() async {
         guard let mapboxMap = mapView?.mapboxMap else {
             return
         }
         
         var features = [Feature]()

         var i = 0
         for coordinate in Constants.locationsSet {
             var feature = Feature(geometry: Point(coordinate))
             feature.identifier = FeatureIdentifier("\(coordinate.latitude), \(coordinate.longitude)")
             var props = [String: JSONValue]()
             props["sortkey"] = JSONValue(integerLiteral: i)
             feature.properties = JSONObject(rawValue: props)
             features.append(feature)
             i += 1
         }

         mapboxMap.updateGeoJSONSource(withId: Constants.sourceId, geoJSON: .featureCollection(FeatureCollection(features: features)).geoJSONObject)
     }

 }

 enum Constants {
     static let aalborgOffice = Point(CLLocationCoordinate2D(latitude: 57.057892242092294,
                                                              longitude: 9.950712725354208))
     
     static let boxNorthWest = CLLocationCoordinate2D(latitude: 57.057782382721, longitude: 9.94823820677511)
     static let boxSouthEast = CLLocationCoordinate2D(latitude: 57.05931227822516, longitude: 9.951910918062843)
     
     static var locationsSet = [CLLocationCoordinate2D]()
     
     static let duckCoordinates = aalborgOffice
     static let iconId = "icon-id"
     static let sourceId = "source-id"
 }

 
