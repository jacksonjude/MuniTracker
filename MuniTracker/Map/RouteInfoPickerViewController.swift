//
//  RouteInfoPickerViewController.swift
//  MuniTracker
//
//  Created by jackson on 6/17/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CoreLocation

class RouteInfoPickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate
{
    var routeInfoToChange = Array<Any>()
    @IBOutlet weak var routeInfoPicker: UIPickerView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var locationButton: UIButton!
    @IBOutlet weak var directionButton: UIButton!
    
    var favoriteFilterEnabled = false
    var locationFilterEnabled = false
    var waitingForLocation = false
    
    //MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRouteData), name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleFavoriteForSelectedStop), name: NSNotification.Name("ToggleFavoriteForStop"), object: nil)
        
        setupThemeElements()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
        
        reloadRouteData()
    }
    
    func setupThemeElements()
    {
        let offWhite = UIColor(white: 0.97647, alpha: 1)
        //let white = UIColor(white: 1, alpha: 1)
        let black = UIColor(white: 0, alpha: 1)
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.routeInfoPicker.backgroundColor = offWhite
            self.favoriteButton.setImage(UIImage(named: "FavoriteIcon"), for: UIControl.State.normal)
            self.locationButton.setImage(UIImage(named: "CurrentLocationIcon"), for: UIControl.State.normal)
            self.directionButton.setImage(UIImage(named: "DirectionIcon"), for: UIControl.State.normal)
        case .dark:
            self.routeInfoPicker.backgroundColor = black
            self.favoriteButton.setImage(UIImage(named: "FavoriteIconDark"), for: UIControl.State.normal)
            self.locationButton.setImage(UIImage(named: "CurrentLocationIconDark"), for: UIControl.State.normal)
            self.directionButton.setImage(UIImage(named: "DirectionIconDark"), for: UIControl.State.normal)
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
    
    func inverseThemeColor() -> UIColor
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            return UIColor.black
        case .dark:
            return UIColor.white
        }
    }
    
    //MARK: - Picker View
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if MapState.routeInfoShowing == .vehicles
        {
            return routeInfoToChange.count + 1
        }
        
        return routeInfoToChange.count
    }
    
    /*func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch MapState.routeInfoShowing
        {
        case .none:
            return nil
        case .direction:
            return (routeInfoToChange[row] as? Direction)?.directionTitle
        case .stop:
            return (routeInfoToChange[row] as? Stop)?.stopTitle
        }
    }*/
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        
        let title: String?
        
        switch MapState.routeInfoShowing
        {
        case .none:
            title = nil
        case .direction:
            title = (routeInfoToChange[row] as? Direction)?.directionTitle
        case .stop:
            title = (routeInfoToChange[row] as? Stop)?.stopTitle
        case .otherDirections:
            //TODO
            title = ""
        case .vehicles:
            //TODO
            if row == 0
            {
                title = "None"
            }
            else
            {
                let vehiclePrediction = (routeInfoToChange[row-1] as? (vehicleID: String, prediction: String))
                title = String(row) + " - " + (vehiclePrediction?.prediction ?? "")
                title! += " mins - id: " + (vehiclePrediction?.vehicleID ?? "")
            }
        }
        
        return NSAttributedString(string: title ?? "", attributes: [NSAttributedString.Key.foregroundColor: inverseThemeColor()])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerSelectedRow()
        
        if locationFilterEnabled
        {
            locationFilterEnabled = false
            locationButton.setImage(UIImage(named: "CurrentLocationIcon" + darkImageAppend()), for: UIControl.State.normal)
        }
    }
    
    //MARK: - Data Reload
    
    @objc func reloadRouteData()
    {
        if MapState.showingPickerView
        {
            routeInfoToChange.removeAll()
            
            var rowToSelect = 0
            
            switch MapState.routeInfoShowing
            {
            case .none:
                self.view.superview!.isHidden = true
            case .direction:
                self.view.superview!.isHidden = false
                
                routeInfoToChange = (MapState.routeInfoObject as? Route)?.directions?.array as? Array<Direction> ?? Array<Direction>()
                
                disableFilterButtons()
                
                var directionOn = 0
                for direction in routeInfoToChange as! Array<Direction>
                {
                    if direction.directionTag == MapState.selectedDirectionTag
                    {
                        rowToSelect = directionOn
                        
                        break
                    }
                    
                    directionOn += 1
                }
            case .stop:
                self.view.superview!.isHidden = false
                
                routeInfoToChange = (MapState.routeInfoObject as? Direction)?.stops?.array as? Array<Stop> ?? Array<Stop>()
                
                enableFilterButtons()
                
                var stopOn = 0
                for stop in routeInfoToChange as! Array<Stop>
                {
                    if stop.stopTag == MapState.selectedStopTag
                    {
                        rowToSelect = stopOn
                        
                        break
                    }
                    
                    stopOn += 1
                }
            case .otherDirections:
                //TODO
                break
            case .vehicles:
                //TODO
                self.view.superview!.isHidden = false
                
                routeInfoToChange = MapState.routeInfoObject as? Array<(vehicleID: String, prediction: String)> ?? Array<(vehicleID: String, prediction: String)>()
                
                disableFilterButtons()
                
                var vehicleOn = 0
                for vehicle in routeInfoToChange as! Array<(vehicleID: String, prediction: String)>
                {
                    if vehicle.vehicleID == MapState.selectedVehicleID
                    {
                        rowToSelect = vehicleOn + 1
                        
                        break
                    }
                    
                    vehicleOn += 1
                }
            }
            
            OperationQueue.main.addOperation {
                self.routeInfoPicker.reloadAllComponents()
                self.routeInfoPicker.selectRow(rowToSelect, inComponent: 0, animated: true)
            
                self.updateSelectedObjectTags()
                
                if self.favoriteFilterEnabled
                {
                    self.filterByFavorites()
                }
                
                if self.locationFilterEnabled
                {
                    if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.location
                    {
                        self.sortStopsByCurrentLocation(location: currentLocation)
                    }
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("UpdateRouteMap"), object: nil, userInfo: ["ChangingRouteInfoShowing":true])
            }
        }
        else
        {
            self.view.superview!.isHidden = true
        }
    }
    
    @IBAction func directionButtonPressed(_ sender: Any) {
        switch MapState.routeInfoShowing
        {
        case .direction:
            MapState.routeInfoShowing = .stop
            MapState.routeInfoObject = routeInfoToChange[routeInfoPicker.selectedRow(inComponent: 0)] as? Direction
            
            enableFilterButtons()
        case .stop:
            MapState.routeInfoShowing = .direction
            MapState.routeInfoObject = (MapState.routeInfoObject as? Direction)?.route
            
            disableFilterButtons()
        default:
            break
        }
        
        reloadRouteData()
    }
    
    func pickerSelectedRow()
    {
        updateSelectedObjectTags()
        NotificationCenter.default.post(name: NSNotification.Name("UpdateRouteMap"), object: nil, userInfo: ["ChangingRouteInfoShowing":false])
    }
    
    func updateSelectedObjectTags()
    {
        let row = routeInfoPicker.selectedRow(inComponent: 0)
        
        if routeInfoToChange.count > row || (MapState.routeInfoShowing == .vehicles && routeInfoToChange.count + 1 > row)
        {
            switch MapState.routeInfoShowing
            {
            case .direction:
                if let direction = routeInfoToChange[row] as? Direction
                {
                    MapState.selectedDirectionTag = direction.directionTag
                }
            case .stop:
                if let stop = routeInfoToChange[row] as? Stop
                {
                    MapState.selectedStopTag = stop.stopTag
                }
            case .vehicles:
                if row == 0
                {
                    MapState.selectedVehicleID = nil
                }
                else if let vehicleID = (routeInfoToChange[row-1] as? (vehicleID: String, prediction: String))?.vehicleID
                {
                    MapState.selectedVehicleID = vehicleID
                }
            default:
                break
            }
        }
    }
    
    //MARK: - Filters
    
    func enableFilterButtons()
    {
        favoriteButton.isHidden = false
        favoriteButton.isEnabled = true
        locationButton.isHidden = false
        locationButton.isEnabled = true
    }
    
    func disableFilterButtons()
    {
        favoriteButton.isHidden = true
        favoriteButton.isEnabled = false
        locationButton.isHidden = true
        locationButton.isEnabled = false
        
        favoriteFilterEnabled = false
        locationFilterEnabled = false
        
        favoriteButton.setImage(UIImage(named: "FavoriteIcon" + darkImageAppend()), for: UIControl.State.normal)
        locationButton.setImage(UIImage(named: "CurrentLocationIcon" + darkImageAppend()), for: UIControl.State.normal)
    }
    
    @IBAction func favoriteFilterButtonPressed(_ sender: Any) {
        favoriteFilterEnabled = !favoriteFilterEnabled
        
        if favoriteFilterEnabled
        {
            favoriteButton.setImage(UIImage(named: "FavoriteFillIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            filterByFavorites()
        }
        else
        {
            favoriteButton.setImage(UIImage(named: "FavoriteIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            reloadRouteData()
        }
    }
    
    @objc func toggleFavoriteForSelectedStop()
    {
        if MapState.routeInfoShowing == .stop
        {
            if let selectedStop = RouteDataManager.getCurrentStop(), let selectedDirection = RouteDataManager.getCurrentDirection()//routeInfoToChange[routeInfoPicker.selectedRow(inComponent: 0)] as? Stop
            {
                let favoriteStopCallback = RouteDataManager.fetchFavoriteStops(directionTag: selectedDirection.directionTag!, stopTag: selectedStop.stopTag)
                if favoriteStopCallback.count > 0
                {
                    appDelegate.persistentContainer.viewContext.delete(favoriteStopCallback[0])
                }
                else
                {
                    let newFavoriteStop = FavoriteStop(context: appDelegate.persistentContainer.viewContext)
                    newFavoriteStop.directionTag = selectedDirection.directionTag
                    newFavoriteStop.stopTag = selectedStop.stopTag
                }
                
                appDelegate.saveContext()
            }
        }
    }
    
    func filterByFavorites()
    {
        if let selectedDirection = RouteDataManager.getCurrentDirection()
        {
            var favoriteStops = Array<Stop>()
            let favoriteStopCallback = RouteDataManager.fetchFavoriteStops(directionTag: selectedDirection.directionTag!)
            for favoriteStop in favoriteStopCallback
            {
                let stop = RouteDataManager.fetchOrCreateObject(type: "Stop", predicate: NSPredicate(format: "stopTag == %@", favoriteStop.stopTag!), moc: appDelegate.persistentContainer.viewContext).object as! Stop
                favoriteStops.append(stop)
            }
            
            routeInfoToChange = favoriteStops
            
            OperationQueue.main.addOperation {
                self.routeInfoPicker.reloadAllComponents()
                
                if self.locationFilterEnabled
                {
                    if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.location
                    {
                        self.sortStopsByCurrentLocation(location: currentLocation)
                    }
                }
                else
                {
                    self.routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
                }
                
                self.pickerSelectedRow()
            }
        }
    }
    
    @IBAction func locationFilterButtonPressed(_ sender: Any) {
        locationFilterEnabled = !locationFilterEnabled
        
        if locationFilterEnabled
        {
            locationButton.setImage(UIImage(named: "CurrentLocationFillIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.location
            {
                sortStopsByCurrentLocation(location: currentLocation)
            }
            
        }
        else
        {
            locationButton.setImage(UIImage(named: "CurrentLocationIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            reloadRouteData()
        }
    }
    
    func sortStopsByCurrentLocation(location: CLLocation)
    {
        if let routeStops = routeInfoToChange as? Array<Stop>
        {
            let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: routeStops, locationToTest: location)
            
            let locationSortType: LocationSortType = (UserDefaults.standard.object(forKey: "LocationSortType") as? Int).map { LocationSortType(rawValue: $0)  ?? .selectClosest } ?? .selectClosest
            
            OperationQueue.main.addOperation {
                switch locationSortType
                {
                case .fullSort:
                    self.routeInfoToChange = sortedStops
                    
                    self.routeInfoPicker.reloadAllComponents()
                    self.routeInfoPicker.selectRow(0, inComponent: 0, animated: true)
                case .selectClosest:
                    if sortedStops.count > 0
                    {
                        self.routeInfoPicker.selectRow(routeStops.firstIndex(of: sortedStops[0]) ?? 0, inComponent: 0, animated: true)
                    }
                }
                
                self.pickerSelectedRow()
            }
        }
    }
}
