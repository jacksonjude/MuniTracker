//
//  ViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import MapKit

let appDelegate = UIApplication.shared.delegate as! AppDelegate

enum AnnotationType
{
    case red
    case orange
}

extension CLLocation
{
    func convertToString() -> String
    {
        return String(self.coordinate.latitude) + "-" + String(self.coordinate.longitude)
    }
}

extension UIImage {
    class func radiansToDegrees(radians: CGFloat) -> CGFloat
    {
        return radians * (180.0 / CGFloat(Double.pi))
    }
    
    class func degreesToRadians(degrees: CGFloat) -> CGFloat
    {
        return degrees / 180.0 * CGFloat(Double.pi)
    }
}

class MainMapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mainMapView: MKMapView!
    @IBOutlet weak var predictionTimesNavigationBar: UINavigationBar!
    @IBOutlet weak var predictionTimesLabel: UILabel!
    @IBOutlet weak var addFavoriteButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var mainNavigationItem: UINavigationItem!
    @IBOutlet weak var mainNavigationBar: UINavigationBar!
    @IBOutlet weak var mainToolbar: UIToolbar!
    @IBOutlet weak var showHidePickerButton: UIBarButtonItem!
    
    //37.773972
    //37.738802
    let initialLocation = CLLocation(latitude: 37.773972, longitude: -122.438765)
    
    var downloadAllData = false
    var progressAlertView: UIAlertController?
    var progressView: UIProgressView?
    
    var selectedAnnotationLocation: String?
    var stopAnnotations = Dictionary<String,StopAnnotation>()
    var directionPolyline: MKPolyline?
    var busAnnotations = Dictionary<String,(annotation: BusAnnotation, annotationView: MKAnnotationView?)>()
    var vehicleIDs = Array<String>()
    
    var locationManager = CLLocationManager()
    
    //MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mainMapView.delegate = self
        mainMapView.showsUserLocation = true
        centerMapOnLocation(location: initialLocation, range: 15000)
        
        setupRouteMapUpdateNotifications()
        
        setupHidePickerButton()
        
        if appDelegate.firstLaunch
        {
            downloadAllData = true
        }
        
        setupThemeElements()
    }
    
    func setupThemeElements()
    {
        let offWhite = UIColor(white: 0.97647, alpha: 1)
        let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.view.backgroundColor = offWhite
            self.predictionTimesNavigationBar.barTintColor = nil
            self.predictionTimesLabel.textColor = black
            self.mainNavigationBar.barTintColor = offWhite
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
            self.mainToolbar.barTintColor = nil
            self.addFavoriteButton.setImage(UIImage(named: "FavoriteAddIcon"), for: UIControl.State.normal)
            self.activityIndicator.activityIndicatorViewStyle = .gray
        case .dark:
            self.view.backgroundColor = black
            self.predictionTimesNavigationBar.barTintColor = black
            self.predictionTimesLabel.textColor = white
            self.mainNavigationBar.barTintColor = black
            self.mainNavigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
            self.mainToolbar.barTintColor = black
            self.addFavoriteButton.setImage(UIImage(named: "FavoriteAddIconDark"), for: UIControl.State.normal)
            self.activityIndicator.activityIndicatorViewStyle = .white
        }
    }
    
    func darkImageAppend() -> String
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            return ""
        case .dark:
            return "Dark"
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            return .default
        case .dark:
            return .lightContent
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if downloadAllData
        {
            progressAlertView = UIAlertController(title: "Updating", message: "Updating route data...\n", preferredStyle: .alert)
            
            self.present(progressAlertView!, animated: true, completion: {
                let margin: CGFloat = 8.0
                let rect = CGRect(x: margin, y: 72.0, width: self.progressAlertView!.view.frame.width - margin * 2.0, height: 2.0)
                self.progressView = UIProgressView(frame: rect)
                self.progressView!.tintColor = UIColor.blue
                self.progressAlertView!.view.addSubview(self.progressView!)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.addToProgress(notification:)), name: NSNotification.Name("CompletedRoute"), object: nil)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.dismissAlertView), name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
                
                DispatchQueue.global(qos: .background).async
                    {
                        RouteDataManager.updateAllData()
                }
            })
            
            downloadAllData = false
        }
        
        setupThemeElements()
    }
    
    //MARK: - Update Routes
    
    @objc func addToProgress(notification: Notification)
    {
        OperationQueue.main.addOperation {
            self.progressView?.progress = notification.userInfo?["progress"] as? Float ?? 0.0
        }
    }
    
    @objc func dismissAlertView()
    {
        progressAlertView?.dismiss(animated: true, completion: {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CompletedRoute"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FinishedUpdatingRoutes"), object: nil)
            
            if appDelegate.firstLaunch && CLLocationManager.authorizationStatus() != .denied
            {
                self.locationManager.requestWhenInUseAuthorization()
            }
        })
    }
    
    //MARK: - Picker View Show/Hide
    
    @objc func showPickerView()
    {
        MapState.showingPickerView = true
        
        self.view.viewWithTag(618)?.isHidden = false
        
        setupHidePickerButton()
    }
    
    @objc func hidePickerView()
    {
        MapState.showingPickerView = false
        
        self.view.viewWithTag(618)?.isHidden = true
        
        setupShowPickerButton()
    }
    
    func setupHidePickerButton()
    {
        showHidePickerButton.title = "Hide"
        showHidePickerButton.target = self
        showHidePickerButton.action = #selector(hidePickerView)
    }
    
    func setupShowPickerButton()
    {
        showHidePickerButton.title = "Show"
        showHidePickerButton.target = self
        showHidePickerButton.action = #selector(showPickerView)
    }
    
    //MARK: - Update Notifications
    
    func setupRouteMapUpdateNotifications()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(updateMap(notification:)), name: NSNotification.Name("UpdateRouteMap"), object: nil)
    }
    
    func removeRouteMapUpdateNotifications()
    {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateRouteMap"), object: nil)
    }
    
    func centerMapOnLocation(location: CLLocation, range: CLLocationDistance, willChangeRange: Bool = true)
    {
        mainMapView.setRegion(MKCoordinateRegion(center: mainMapView.region.center, latitudinalMeters: range, longitudinalMeters: range), animated: false)
        
        let offset = self.view.viewWithTag(618)?.frame.height ?? 0
        
        var point = mainMapView.convert(location.coordinate, toPointTo: self.view)
        point.y += offset/2
        let offsetCoordinate = mainMapView.convert(point, toCoordinateFrom: self.view)
        
        mainMapView.setRegion(MKCoordinateRegion(center: offsetCoordinate, latitudinalMeters: range, longitudinalMeters: range), animated: !willChangeRange)
    }
    
    @objc func updateMap(notification: Notification)
    {
        switch MapState.routeInfoShowing
        {
        case .none:
            resetAnnotations()
            
            hidePredictionNavigationBar()
            
            showHidePickerButton.isEnabled = false
        case .direction:
            resetAnnotations()
            
            if let direction = RouteDataManager.getCurrentDirection()
            {
                for stop in direction.stops!.array
                {
                    let stop = stop as! Stop
                    addAnnotation(coordinate: CLLocationCoordinate2D(latitude: stop.stopLatitude, longitude: stop.stopLongitude))
                }
                
                reloadPolyline()
                
                fetchVehicleLocations()
            }
            
            centerMapOnLocation(location: initialLocation, range: 15000)
            
            hidePredictionNavigationBar()
            
            showHidePickerButton.isEnabled = true
        case .stop:
            let changingRouteInfoShowing = notification.userInfo!["ChangingRouteInfoShowing"] as! Bool
            
            if let stop = RouteDataManager.getCurrentStop()
            {
                let stopLocation = CLLocation(latitude: stop.stopLatitude, longitude: stop.stopLongitude)
                
                centerMapOnLocation(location: stopLocation, range: 1000, willChangeRange: changingRouteInfoShowing)
                
                setAnnotationType(coordinate: selectedAnnotationLocation, annotationType: .red)
                setAnnotationType(coordinate: stopLocation.convertToString(), annotationType: .orange)
                
                selectedAnnotationLocation = stopLocation.convertToString()
            }
            
            showPredictionNavigationBar()
            
            refreshPredictionNavigationBar()
            
            if changingRouteInfoShowing
            {
                reloadPolyline()
            }
            
            setFavoriteButtonImage(inverse: false)
            
            showHidePickerButton.isEnabled = true
        }
    }
    
    //MARK: - Annotations
    
    func addAnnotation(coordinate: CLLocationCoordinate2D, annotationType: AnnotationType = .red)
    {
        let annotation = StopAnnotation(coordinate: coordinate, annotationType: annotationType)
        
        mainMapView.addAnnotation(annotation)
        stopAnnotations[CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).convertToString()] = annotation
    }
    
    func setAnnotationType(coordinate: String?, annotationType: AnnotationType)
    {
        if coordinate != nil
        {
            if let annotation = stopAnnotations[coordinate!]
            {
                mainMapView.removeAnnotation(annotation)
                annotation.type = annotationType
                mainMapView.addAnnotation(annotation)
            }
        }
    }
    
    func resetAnnotations()
    {
        mainMapView.removeAnnotations(mainMapView.annotations)
        stopAnnotations.removeAll()
        busAnnotations.removeAll()
        vehicleIDs.removeAll()
        RouteDataManager.lastVehicleTime = nil
        
        if directionPolyline != nil
        {
            mainMapView.removeOverlay(directionPolyline!)
        }
    }
    
    func reloadPolyline()
    {
        if directionPolyline != nil
        {
            mainMapView.removeOverlay(directionPolyline!)
        }
        
        if let direction = RouteDataManager.getCurrentDirection()
        {
            var coordinates = Array<CLLocationCoordinate2D>()
            
            for stop in direction.stops!.array
            {
                if let stop = stop as? Stop
                {
                    coordinates.append(CLLocationCoordinate2D(latitude: stop.stopLatitude, longitude: stop.stopLongitude))
                }
            }
            
            directionPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mainMapView.addOverlay(directionPolyline!)
        }
    }
    
    //MARK: - Map Delegate Calls
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        polylineRenderer.strokeColor = UIColor(red: 0.972, green: 0.611, blue: 0.266, alpha: 1)
        polylineRenderer.lineWidth = 5
        return polylineRenderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let stopAnnotation = annotation as? StopAnnotation
        {
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
            
            switch stopAnnotation.type
            {
            case .red:
                annotationView.image = UIImage(named: "RedDot")
            case .orange:
                annotationView.image = UIImage(named: "OrangeDot")
            }
            
            return annotationView
        }
        else if annotation is BusAnnotation
        {
            if let annotationView = busAnnotations[(annotation as! BusAnnotation).id]?.annotationView
            {
                UIView.animate(withDuration: 1) {
                    annotationView.annotation = annotation
                }
                
                return annotationView
            }
            
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
            
            annotationView.image = UIImage(named: "BusAnnotation")
            annotationView.centerOffset = CGPoint(x: 0, y: -annotationView.image!.size.height/2)
            
            (annotation as! BusAnnotation).headingAnnotation?.busAnnotationViewImageSize = annotationView.image?.size
            
            busAnnotations[(annotation as! BusAnnotation).id]?.annotationView = annotationView
            
            return annotationView
        }
        else if let headingAnnotation = annotation as? HeadingAnnotation
        {
            let headingImage = UIImage(named: "HeadingIndicator")!//?.imageRotatedByDegrees(deg: CGFloat(headingAnnotation.headingValue))
            
            let busImageSize = headingAnnotation.busAnnotationViewImageSize ?? UIImage(named: "BusAnnotation")!.size
            
            let xOffset = (busImageSize.width/2+(headingImage.size.height/2)*1.5) * cos(UIImage.degreesToRadians(degrees: CGFloat(headingAnnotation.headingValue - 90)))
            let yOffset = (busImageSize.width/2+(headingImage.size.height/2)*1.5) * sin(UIImage.degreesToRadians(degrees: CGFloat(headingAnnotation.headingValue - 90)))
            
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
            annotationView.centerOffset = CGPoint(x: xOffset, y: yOffset - busImageSize.height/2)
            annotationView.image = headingImage
            
            //annotationView.displayPriority = MKFeatureDisplayPriority.defaultHigh
            let t: CGAffineTransform = CGAffineTransform(rotationAngle: CGFloat(headingAnnotation.headingValue) * CGFloat.pi / 180)
            annotationView.transform = t
            
            return annotationView
        }
        else if annotation is MKUserLocation
        {
            return nil
        }
        
        return nil
    }
    
    //MARK: - Segue
    
    @IBAction func routesButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "showRoutesTableView", sender: self)
    }
    
    @IBAction func unwindFromRouteTableViewWithSelectedRoute(_ segue: UIStoryboardSegue)
    {
        MapState.showingPickerView = true
        setupHidePickerButton()
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
    }
    
    @IBAction func unwindFromRouteTableView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    @IBAction func unwindFromSettingsView(_ segue: UIStoryboardSegue)
    {
        
    }
    
    //MARK: - Bus Predications
    
    func showPredictionNavigationBar()
    {
        UIView.animate(withDuration: 1) {
            self.predictionTimesNavigationBar.isHidden = false
            self.addFavoriteButton.isEnabled = true
            self.addFavoriteButton.isHidden = false
        }
    }
    
    func hidePredictionNavigationBar()
    {
        UIView.animate(withDuration: 1) {
            self.predictionTimesNavigationBar.isHidden = true
            self.addFavoriteButton.isEnabled = false
            self.addFavoriteButton.isHidden = true
        }
    }
    
    @IBAction func refreshPredictionNavigationBar()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchVehicleLocations), name: NSNotification.Name("FetchVehicleLocations"), object: nil)
        
        fetchPredictionTimes()
    }
    
    func fetchPredictionTimes()
    {
        let predictionTimesReturnUUID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receivePredictionTimes(_:)), name: NSNotification.Name("FoundPredictions:" + predictionTimesReturnUUID), object: nil)
        RouteDataManager.fetchPredictionTimesForStop(returnUUID: predictionTimesReturnUUID)
        
        OperationQueue.main.addOperation {
            self.refreshButton.isEnabled = false
            self.refreshButton.tintColor = .clear
            self.activityIndicator.startAnimating()
        }
    }
    
    @objc func fetchVehicleLocations()
    {
        let vehicleLocationsReturnUUID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveVehicleLocations(_:)), name: NSNotification.Name("FoundVehicleLocations:" + vehicleLocationsReturnUUID), object: nil)
        RouteDataManager.fetchVehicleLocations(returnUUID: vehicleLocationsReturnUUID, vehicleIDs: vehicleIDs)
    }
    
    @objc func receivePredictionTimes(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        OperationQueue.main.addOperation {
            self.refreshButton.isEnabled = true
            self.refreshButton.tintColor = UIColor(red: 0, green: 0.4, blue: 1.0, alpha: 1)
            self.activityIndicator.stopAnimating()
        }
        
        if let predictions = notification.userInfo!["predictions"] as? Array<String>
        {
            var predictionsString = ""
            var predictionOn = 0
            
            for prediction in predictions
            {
                if predictionOn != 0
                {
                    predictionsString += ", "
                }
                
                if prediction == "0"
                {
                    predictionsString += "Now"
                }
                else
                {
                    predictionsString += prediction
                }
                
                predictionOn += 1
            }
            
            if predictions.count > 0
            {
                if predictions.count > 1 || predictions[0] != "0"
                {
                    predictionsString += " mins"
                }
            }
            else
            {
                predictionsString = "No Predictions"
            }
            
            OperationQueue.main.addOperation {
                self.predictionTimesLabel.text = predictionsString
            }
        }
        else if let error = notification.userInfo!["error"] as? String
        {
            OperationQueue.main.addOperation {
                self.predictionTimesLabel.text = error
            }
        }
        
        if let vehicleIDs = notification.userInfo!["vehicleIDs"] as? Array<String>
        {
            self.vehicleIDs = vehicleIDs
            
            NotificationCenter.default.post(name: NSNotification.Name("FetchVehicleLocations"), object: nil)
        }
    }
    
    @objc func receiveVehicleLocations(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        
        OperationQueue.main.addOperation {
            
        }
        
        OperationQueue.main.addOperation {
            var annotationsToSave = Dictionary<String,(annotation: BusAnnotation, annotationView: MKAnnotationView?)>()
            
            let vehicleLocations = notification.userInfo!["vehicleLocations"] as! Array<(id: String, location: CLLocation, heading: Int)>
            for vehicleLocation in vehicleLocations
            {
                if let busAnnotationTuple = self.busAnnotations[vehicleLocation.id]
                {
                    busAnnotationTuple.annotation.coordinate = vehicleLocation.location.coordinate
                    busAnnotationTuple.annotation.heading = vehicleLocation.heading
                }
                else
                {
                    self.busAnnotations[vehicleLocation.id] = (annotation: BusAnnotation(coordinate: vehicleLocation.location.coordinate, heading: vehicleLocation.heading, id: vehicleLocation.id), annotationView: nil)
                }
                
                if let annotationView = self.busAnnotations[vehicleLocation.id]?.annotationView
                {
                    UIView.animate(withDuration: 1) {
                        annotationView.annotation = self.busAnnotations[vehicleLocation.id]!.annotation
                    }
                }
                else
                {
                    self.mainMapView.addAnnotation(self.busAnnotations[vehicleLocation.id]!.annotation)
                }
                
                if let headingAnnotation = self.busAnnotations[vehicleLocation.id]!.annotation.headingAnnotation
                {
                    self.mainMapView.removeAnnotation(headingAnnotation)
                }
                
                let headingAnnotation = HeadingAnnotation(coordinate: vehicleLocation.location.coordinate, heading: vehicleLocation.heading)
                self.mainMapView.addAnnotation(headingAnnotation)
                
                self.busAnnotations[vehicleLocation.id]?.annotation.headingAnnotation = headingAnnotation
                
                annotationsToSave[vehicleLocation.id] = self.busAnnotations[vehicleLocation.id]
            }
            
            for annotation in annotationsToSave
            {
                self.busAnnotations.removeValue(forKey: annotation.key)
            }
            
            for annotation in self.busAnnotations
            {
                self.mainMapView.removeAnnotation(annotation.value.annotation)
                if let headingAnnotation = annotation.value.annotation.headingAnnotation
                {
                    self.mainMapView.removeAnnotation(headingAnnotation)
                }
            }
            
            self.busAnnotations = annotationsToSave
        }
    }
    
    //MARK: - Add Favorite
    
    @IBAction func addFavoriteButtonPressed(_ sender: Any) {
        setFavoriteButtonImage(inverse: true)
        
        NotificationCenter.default.post(name: NSNotification.Name("ToggleFavoriteForStop"), object: nil)
    }
    
    func setFavoriteButtonImage(inverse: Bool)
    {
        if MapState.selectedStopTag != nil
        {
            if let stop = RouteDataManager.getCurrentStop(), let direction = RouteDataManager.getCurrentDirection()
            {
                var stopIsFavorite = RouteDataManager.favoriteStopExists(stopTag: stop.stopTag!, directionTag: direction.directionTag!)
                if inverse
                {
                    stopIsFavorite = !stopIsFavorite
                }
                
                if stopIsFavorite
                {
                    addFavoriteButton.setImage(UIImage(named:  "FavoriteAddFillIcon" + darkImageAppend()), for: UIControl.State.normal)
                }
                else
                {
                    addFavoriteButton.setImage(UIImage(named: "FavoriteAddIcon" + darkImageAppend()), for: UIControl.State.normal)
                }
            }
        }
    }
}

class StopAnnotation: NSObject, MKAnnotation
{
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var type: AnnotationType = .red
    
    init(coordinate: CLLocationCoordinate2D, annotationType: AnnotationType = .red)
    {
        self.coordinate = coordinate
        self.type = annotationType
    }
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, annotationType: AnnotationType = .red)
    {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = annotationType
    }
}

class BusAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate: CLLocationCoordinate2D
    var heading: Int
    var id: String
    var title: String?
    var subtitle: String?
    var headingAnnotation: HeadingAnnotation?
    
    init(coordinate: CLLocationCoordinate2D, heading: Int, id: String)
    {
        self.coordinate = coordinate
        self.heading = heading
        self.id = id
    }
}

class HeadingAnnotation: NSObject, MKAnnotation
{
    dynamic var coordinate: CLLocationCoordinate2D
    var headingValue: Int
    var title: String?
    var subtitle: String?
    var busAnnotationViewImageSize: CGSize?
    
    init(coordinate: CLLocationCoordinate2D, heading: Int)
    {
        self.coordinate = coordinate
        self.headingValue = heading
    }
}