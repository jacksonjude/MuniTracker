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
    //@IBOutlet weak var favoriteButton: UIButton!
    //@IBOutlet weak var locationButton: UIButton!
    @IBOutlet weak var directionButton: UIButton!
    @IBOutlet weak var otherDirectionsButton: UIButton!
    @IBOutlet weak var addFavoriteButton: UIButton!
    @IBOutlet weak var addNotificationButton: UIButton!
    //@IBOutlet weak var favoriteButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var expandFiltersButton: UIButton!
    
    var favoriteFilterEnabled = false
    var locationFilterEnabled = false
    var waitingForLocation = false
    var filtersExpanded = false
    
    //MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRouteData), name: NSNotification.Name("ReloadRouteInfoPicker"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleFavoriteForSelectedStop), name: NSNotification.Name("ToggleFavoriteForStop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableFilters), name: NSNotification.Name("DisableFilters"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectCurrentStop), name: NSNotification.Name("SelectCurrentStop"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(collapseFilters), name: NSNotification.Name("CollapseFilters"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enableFilters), name: NSNotification.Name("EnableFilters"), object: nil)
        
        setFavoriteButtonImage(inverse: false)
        setupThemeElements()
        
        setupFilterButtons()
    }
    
    func setupFilterButtons()
    {
        let favoriteButton = FilterButton(imagePath: "Favorite", superview: self.view)
        let locationButton = FilterButton(imagePath: "CurrentLocation", superview: self.view)
        favoriteButton.singleTapHandler = {
            self.favoriteFilterButtonPressed(favoriteButton)
            favoriteButton.filterIsEnabled = self.favoriteFilterEnabled
        }
        locationButton.singleTapHandler = {
            self.locationFilterButtonPressed(locationButton)
            locationButton.filterIsEnabled = self.locationFilterEnabled
        }
        filterButtons.append(locationButton)
        filterButtons.append(favoriteButton)
    }
    
    var viewDidJustAppear = false
    
    override func viewDidAppear(_ animated: Bool) {
        setupThemeElements()
        if !viewDidJustAppear
        {
            reloadRouteData()
            viewDidJustAppear = true
        }
    }
    
    override func viewWillLayoutSubviews() {
        setupThemeElements()
    }
    
    func setupThemeElements()
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            for filterButton in filterButtons
            {
                filterButton.setFilterImage()
            }
            self.directionButton.setImage(UIImage(named: "DirectionIcon"), for: UIControl.State.normal)
            self.otherDirectionsButton.setImage(UIImage(named: "BusStopIcon"), for: UIControl.State.normal)
            self.expandFiltersButton.setImage(UIImage(named: "FilterIcon"), for: UIControl.State.normal)
            self.addNotificationButton.setImage(UIImage(named: "BellAddIcon"), for: UIControl.State.normal)
            setFavoriteButtonImage(inverse: false)
        case .dark:
            for filterButton in filterButtons
            {
                filterButton.setFilterImage()
            }
            self.directionButton.setImage(UIImage(named: "DirectionIconDark"), for: UIControl.State.normal)
            self.otherDirectionsButton.setImage(UIImage(named: "BusStopIconDark"), for: UIControl.State.normal)
            self.expandFiltersButton.setImage(UIImage(named: "FilterIconDark"), for: UIControl.State.normal)
             self.addNotificationButton.setImage(UIImage(named: "BellAddIconDark"), for: UIControl.State.normal)
            setFavoriteButtonImage(inverse: false)
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
    
    func locationFillAppend() -> String
    {
        if locationFilterEnabled
        {
            return "Fill"
        }
        else
        {
            return ""
        }
    }
    
    func favoriteFillAppend() -> String
    {
        if favoriteFilterEnabled
        {
            return "Fill"
        }
        else
        {
            return ""
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
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        
        var title: String?
        
        switch MapState.routeInfoShowing
        {
        case .none:
            title = nil
        case .direction:
            title = (routeInfoToChange[row] as? Direction)?.directionTitle
        case .stop:
            title = (routeInfoToChange[row] as? Stop)?.stopTitle
        case .otherDirections:
            let routeTitle = (routeInfoToChange[row] as? Direction)?.route?.routeTitle ?? ""
            let directionName = (routeInfoToChange[row] as? Direction)?.directionName ?? ""
            
            title = routeTitle + " - " + directionName
        case .vehicles:
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
        
        return NSAttributedString(string: title ?? "", attributes: [:])
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerSelectedRow()
        
        if locationFilterEnabled
        {
            locationFilterEnabled = false
            //locationButton.setImage(UIImage(named: "CurrentLocationIcon" + darkImageAppend()), for: UIControl.State.normal)
        }
        
        for filterButton in filterButtons
        {
            if filterButton.imagePath == "CurrentLocation"
            {
                filterButton.filterIsEnabled = locationFilterEnabled
                filterButton.setFilterImage()
            }
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
                
                directionButton.isHidden = false
                directionButton.isEnabled = true
                
                otherDirectionsButton.isHidden = true
                otherDirectionsButton.isEnabled = false
                
                addFavoriteButton.isHidden = true
                addFavoriteButton.isEnabled = false
                addNotificationButton.isHidden = true
                addNotificationButton.isEnabled = false
                
                rowToSelect = (routeInfoToChange as! Array<Direction>).firstIndex(of: (routeInfoToChange as! Array<Direction>).filter({$0.directionTag == MapState.selectedDirectionTag}).first ?? (routeInfoToChange as! Array<Direction>)[0]) ?? 0
            case .stop:
                self.view.superview!.isHidden = false
                
                routeInfoToChange = (MapState.routeInfoObject as? Direction)?.stops?.array as? Array<Stop> ?? Array<Stop>()
                
                showFilterButtons()
                
                directionButton.isHidden = false
                directionButton.isEnabled = true
                
                otherDirectionsButton.isHidden = false
                otherDirectionsButton.isEnabled = true
                
                addFavoriteButton.isHidden = false
                addFavoriteButton.isEnabled = true
                addNotificationButton.isHidden = false
                addNotificationButton.isEnabled = true
                
                rowToSelect = (routeInfoToChange as! Array<Stop>).firstIndex(of: (routeInfoToChange as! Array<Stop>).filter({$0.stopTag == MapState.selectedStopTag}).first ?? (routeInfoToChange as! Array<Stop>)[0]) ?? 0
            case .otherDirections:
                self.view.superview!.isHidden = false
                
                routeInfoToChange = MapState.routeInfoObject as? Array<Direction> ?? Array<Direction>()
                
                disableFilterButtons()
                
                directionButton.isHidden = true
                directionButton.isEnabled = false
                
                addFavoriteButton.isHidden = true
                addFavoriteButton.isEnabled = false
                addNotificationButton.isHidden = true
                addNotificationButton.isEnabled = false
                
                rowToSelect = (routeInfoToChange as! Array<Direction>).firstIndex(of: (routeInfoToChange as! Array<Direction>).filter({$0.directionTag == MapState.selectedDirectionTag}).first ?? (routeInfoToChange as! Array<Direction>)[0]) ?? 0
            case .vehicles:
                self.view.superview!.isHidden = false
                
                routeInfoToChange = MapState.routeInfoObject as? Array<(vehicleID: String, prediction: String)> ?? Array<(vehicleID: String, prediction: String)>()
                
                disableFilterButtons()
                
                directionButton.isHidden = true
                directionButton.isEnabled = false
                
                otherDirectionsButton.isHidden = true
                otherDirectionsButton.isEnabled = false
                
                addFavoriteButton.isHidden = true
                addFavoriteButton.isEnabled = false
                addNotificationButton.isHidden = true
                addNotificationButton.isEnabled = false
                
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
                if self.favoriteFilterEnabled
                {
                    self.filterByFavorites()
                }
                else if self.locationFilterEnabled
                {
                    self.routeInfoPicker.reloadAllComponents()
                    
                    if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.location
                    {
                        self.sortStopsByCurrentLocation(location: currentLocation)
                    }
                }
                else
                {
                    self.routeInfoPicker.reloadAllComponents()
                    self.routeInfoPicker.selectRow(rowToSelect, inComponent: 0, animated: true)
                    
                    self.updateSelectedObjectTags()
                    
                    self.setFavoriteButtonImage(inverse: false)
                }
                
                if self.routeInfoToChange.count == 0
                {
                    self.addFavoriteButton.isHidden = true
                    self.addFavoriteButton.isEnabled = false
                    self.addNotificationButton.isHidden = true
                    self.addNotificationButton.isEnabled = false
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
        case .stop:
            let route = (MapState.routeInfoObject as? Direction)?.route
            
            if route?.directions?.count == 2
            {
                var directionArray = route!.directions!.array as! [Direction]
                directionArray.remove(at: directionArray.firstIndex(of: (MapState.routeInfoObject as! Direction))!)
                MapState.routeInfoObject = directionArray[0]
                MapState.selectedDirectionTag = directionArray[0].directionTag
                
                if let selectedStop = MapState.getCurrentStop(), let stops = directionArray[0].stops?.array as? [Stop]
                {
                    let sortedStops = RouteDataManager.sortStopsByDistanceFromLocation(stops: stops, locationToTest: CLLocation(latitude: selectedStop.stopLatitude, longitude: selectedStop.stopLongitude))
                    MapState.selectedStopTag = sortedStops[0].stopTag
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("ReloadAnnotations"), object: nil)
            }
            else
            {
                MapState.routeInfoShowing = .direction
                MapState.routeInfoObject = (MapState.routeInfoObject as? Direction)?.route
            }
        default:
            break
        }
        
        reloadRouteData()
    }
    
    func pickerSelectedRow()
    {
        updateSelectedObjectTags()
        NotificationCenter.default.post(name: NSNotification.Name("UpdateRouteMap"), object: nil, userInfo: ["ChangingRouteInfoShowing":false])
        setFavoriteButtonImage(inverse: false)
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
                    
                    updateRecentStops()
                }
            case .otherDirections:
                if let direction = routeInfoToChange[row] as? Direction
                {
                    MapState.selectedDirectionTag = direction.directionTag
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
    
    func updateRecentStops()
    {
        CoreDataStack.persistentContainer.performBackgroundTask { (backgroundMOC) in
            if let mapStateDirectionTag = MapState.selectedDirectionTag, let currentRecentStopUUID = MapState.currentRecentStopUUID, let currentRecentStopArray = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: "uuid == %@", currentRecentStopUUID), moc: backgroundMOC) as? [RecentStop], currentRecentStopArray.count > 0
            {
                let currentRecentStop = currentRecentStopArray[0]
                
                if currentRecentStop.directionTag != nil && RouteDataManager.fetchDirection(directionTag: currentRecentStop.directionTag!)?.route?.routeTag == RouteDataManager.fetchDirection(directionTag: mapStateDirectionTag)?.route?.routeTag
                {
                    if self.checkForDuplicateRecentStop(backgroundMOC: backgroundMOC, uuidToNotMatch: currentRecentStop.uuid!)
                    {
                        backgroundMOC.delete(currentRecentStop)
                    }
                    else
                    {
                        currentRecentStop.directionTag = MapState.selectedDirectionTag
                        currentRecentStop.stopTag = MapState.selectedStopTag
                        currentRecentStop.timestamp = Date()
                    }
                }
                else
                {
                    if !self.checkForDuplicateRecentStop(backgroundMOC: backgroundMOC, uuidToNotMatch: currentRecentStop.uuid!)
                    {
                        self.insertNewRecentStop(backgroundMOC: backgroundMOC)
                    }
                }
            }
            else if MapState.selectedDirectionTag != nil && MapState.selectedStopTag != nil
            {
                if !self.checkForDuplicateRecentStop(backgroundMOC: backgroundMOC)
                {
                    self.insertNewRecentStop(backgroundMOC: backgroundMOC)
                }
            }
            
            if var oldRecentStops = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(value: true), moc: backgroundMOC, sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)]) as? [RecentStop], oldRecentStops.count > 20
            {
                oldRecentStops = Array<RecentStop>(oldRecentStops[20...oldRecentStops.count-1])
                for oldStop in oldRecentStops
                {
                    backgroundMOC.delete(oldStop)
                }
            }
            
            try? backgroundMOC.save()
        }
    }
    
    func insertNewRecentStop(backgroundMOC: NSManagedObjectContext)
    {
        let recentStop = NSEntityDescription.insertNewObject(forEntityName: "RecentStop", into: backgroundMOC) as! RecentStop
        recentStop.directionTag = MapState.selectedDirectionTag
        recentStop.stopTag = MapState.selectedStopTag
        recentStop.timestamp = Date()
        recentStop.uuid = UUID().uuidString
        MapState.currentRecentStopUUID = recentStop.uuid
    }
    
    func checkForDuplicateRecentStop(backgroundMOC: NSManagedObjectContext, uuidToNotMatch: String? = nil) -> Bool
    {
        var predicateFormat = "directionTag == %@ AND stopTag == %@"
        if uuidToNotMatch != nil
        {
            predicateFormat += " AND uuid != %@"
        }
        if let duplicateRecentStopArray = RouteDataManager.fetchLocalObjects(type: "RecentStop", predicate: NSPredicate(format: predicateFormat, MapState.selectedDirectionTag!, MapState.selectedStopTag!, uuidToNotMatch ?? ""), moc: backgroundMOC) as? [RecentStop]
        {
            if duplicateRecentStopArray.count > 0
            {
                let recentStopToBringToFront = duplicateRecentStopArray[0]
                recentStopToBringToFront.timestamp = Date()
                MapState.currentRecentStopUUID = recentStopToBringToFront.uuid
                
                //backgroundMOC.delete(currentRecentStop)
                
                return true
            }
            
            return false
        }
        
        return false
    }
    
    @objc func selectCurrentStop()
    {
        if !favoriteFilterEnabled
        {
            if MapState.routeInfoShowing == .stop, let stops = routeInfoToChange as? Array<Stop>
            {
                self.routeInfoPicker.selectRow(stops.firstIndex(of: stops.first(where: {$0.stopTag == MapState.selectedStopTag})!) ?? 0, inComponent: 0, animated: true)
                
                pickerSelectedRow()
            }
        }
    }
    
    //MARK: - Filters
    
    var filterButtons = [FilterButton]()
    
    func showFilterButtons()
    {
        if filtersExpanded
        {
            /*favoriteButton.isHidden = false
            favoriteButton.isEnabled = true
            locationButton.isHidden = false
            locationButton.isEnabled = true*/
            filterButtons.forEach { (filterButton) in
                filterButton.enableButton()
                //filterButton.setFilterImage()
            }
        }
        else
        {
            expandFiltersButton.isHidden = false
            expandFiltersButton.isEnabled = true
        }
    }
    
    func disableFilterButtons()
    {
        filtersExpanded = false
        
        expandFiltersButton.isHidden = true
        expandFiltersButton.isEnabled = false
        
        /*favoriteButton.isHidden = true
        favoriteButton.isEnabled = false
        locationButton.isHidden = true
        locationButton.isEnabled = false*/
        filterButtons.forEach { (filterButton) in
            filterButton.disableButton()
        }
        
        disableFilters()
    }
    
    @IBAction func expandFilters()
    {
        filtersExpanded = true
        
        expandFiltersButton.isHidden = true
        expandFiltersButton.isEnabled = false
        
        showFilterButtons()
        
        //favoriteButtonLeadingConstraint.constant = -1*(favoriteButton.frame.size.height)
        
        for filterButton in filterButtons
        {
            filterButton.leadingConstraint?.constant = -8
        }
        
        self.view.layoutSubviews()
        
        var filterButtonNumber: CGFloat = 0
        for filterButton in filterButtons
        {
            filterButton.leadingConstraint?.constant = -1*(((filterButton.frame.size.height)*filterButtonNumber) + (8*(filterButtonNumber+1)))
            filterButtonNumber += 1
        }
        //favoriteButtonLeadingConstraint.constant = 8
        
        UIView.animate(withDuration: 0.5) {
            self.view.layoutSubviews()
        }
    }
    
    @objc func collapseFilters()
    {
        filtersExpanded = false
        
        //favoriteButtonLeadingConstraint.constant = -1*(favoriteButton.frame.size.height)
        for filterButton in filterButtons
        {
            filterButton.leadingConstraint?.constant = -8
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutSubviews()
        }) { (bool) in
            /*self.favoriteButton.isHidden = true
            self.favoriteButton.isEnabled = false
            self.locationButton.isHidden = true
            self.locationButton.isEnabled = false*/
            
            for filterButton in self.filterButtons
            {
                filterButton.disableButton()
            }
            
            if MapState.routeInfoShowing == .stop
            {
                self.expandFiltersButton.isHidden = false
                self.expandFiltersButton.isEnabled = true
            }
        }
    }
    
    @objc func disableFilters()
    {
        favoriteFilterEnabled = false
        locationFilterEnabled = false
        
        /*favoriteButton.setImage(UIImage(named: "FavoriteIcon" + darkImageAppend()), for: UIControl.State.normal)
        locationButton.setImage(UIImage(named: "CurrentLocationIcon" + darkImageAppend()), for: UIControl.State.normal)*/
        
        for filterButton in filterButtons
        {
            filterButton.filterIsEnabled = false
            filterButton.setFilterImage()
        }
    }
    
    @objc func enableFilters()
    {
        expandFilters()
        
        favoriteFilterEnabled = true
        locationFilterEnabled = true
        
        /*favoriteButton.setImage(UIImage(named: "FavoriteFillIcon" + darkImageAppend()), for: UIControl.State.normal)
        locationButton.setImage(UIImage(named: "CurrentLocationFillIcon" + darkImageAppend()), for: UIControl.State.normal)*/
        
        for filterButton in filterButtons
        {
            filterButton.filterIsEnabled = true
            filterButton.setFilterImage()
        }
    }
    
    @IBAction func favoriteFilterButtonPressed(_ sender: Any) {
        favoriteFilterEnabled = !favoriteFilterEnabled
        
        if favoriteFilterEnabled
        {
            //favoriteButton.setImage(UIImage(named: "FavoriteFillIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            filterByFavorites()
        }
        else
        {
            //favoriteButton.setImage(UIImage(named: "FavoriteIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            reloadRouteData()
        }
    }
    
    @objc func toggleFavoriteForSelectedStop()
    {
        if MapState.routeInfoShowing == .stop
        {
            if let selectedStop = MapState.getCurrentStop(), let selectedDirection = MapState.getCurrentDirection()//routeInfoToChange[routeInfoPicker.selectedRow(inComponent: 0)] as? Stop
            {
                let favoriteStopCallback = RouteDataManager.fetchFavoriteStops(directionTag: selectedDirection.directionTag!, stopTag: selectedStop.stopTag)
                if favoriteStopCallback.count > 0
                {
                    CoreDataStack.persistentContainer.viewContext.delete(favoriteStopCallback[0])
                    
                    CloudManager.addToLocalChanges(type: ManagedObjectChangeType.delete, uuid: favoriteStopCallback[0].uuid!)
                    NotificationCenter.default.addObserver(self, selector: #selector(didSaveFavoriteStop), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
                }
                else
                {
                    let newFavoriteStop = FavoriteStop(context: CoreDataStack.persistentContainer.viewContext)
                    newFavoriteStop.directionTag = selectedDirection.directionTag
                    newFavoriteStop.stopTag = selectedStop.stopTag
                    newFavoriteStop.uuid = UUID().uuidString
                    
                    CloudManager.addToLocalChanges(type: ManagedObjectChangeType.insert, uuid: newFavoriteStop.uuid!)
                    NotificationCenter.default.addObserver(self, selector: #selector(didSaveFavoriteStop), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
                }
                
                CoreDataStack.saveContext()
            }
        }
    }
    
    @objc func didSaveFavoriteStop(notification: Notification)
    {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
        CloudManager.syncToCloud()
    }
    
    func filterByFavorites()
    {
        if let selectedDirection = MapState.getCurrentDirection()
        {
            var favoriteStops = Array<Stop>()
            let favoriteStopCallback = RouteDataManager.fetchFavoriteStops(directionTag: selectedDirection.directionTag!)
            for favoriteStop in favoriteStopCallback
            {
                let stop = RouteDataManager.fetchStop(stopTag: favoriteStop.stopTag!)!
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
                    
                    self.pickerSelectedRow()
                }
                
                if self.routeInfoToChange.count == 0
                {
                    self.addFavoriteButton.isHidden = true
                    self.addFavoriteButton.isEnabled = false
                }
            }
        }
    }
    
    @IBAction func locationFilterButtonPressed(_ sender: Any) {
        locationFilterEnabled = !locationFilterEnabled
        
        if locationFilterEnabled
        {
            //locationButton.setImage(UIImage(named: "CurrentLocationFillIcon" + darkImageAppend()), for: UIControl.State.normal)
            
            if let currentLocation = appDelegate.mainMapViewController?.mainMapView.userLocation.location
            {
                sortStopsByCurrentLocation(location: currentLocation)
            }
            
        }
        else
        {
            //locationButton.setImage(UIImage(named: "CurrentLocationIcon" + darkImageAppend()), for: UIControl.State.normal)
            
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
    
    //MARK: - Other Directions
    
    @IBAction func otherDirectionsButtonPressed(_ sender: Any) {
        if let selectedStop = MapState.getCurrentStop()
        {
            MapState.routeInfoObject = selectedStop.direction?.allObjects
            appDelegate.mainMapViewController?.performSegue(withIdentifier: "showOtherDirectionsTableView", sender: self)
        }
    }
    
    //MARK: - Add Favorite / Notification
    
    @IBAction func addFavoriteButtonPressed(_ sender: Any) {
        setFavoriteButtonImage(inverse: true)
        
        toggleFavoriteForSelectedStop()
    }
    
    func setFavoriteButtonImage(inverse: Bool)
    {
        if MapState.selectedStopTag != nil
        {
            if let stop = MapState.getCurrentStop(), let direction = MapState.getCurrentDirection()
            {
                var stopIsFavorite = RouteDataManager.favoriteStopExists(stopTag: stop.stopTag!, directionTag: direction.directionTag!)
                if inverse
                {
                    stopIsFavorite = !stopIsFavorite
                }
                
                if stopIsFavorite
                {
                    addFavoriteButton.setImage(UIImage(named:  "FavoriteAddFillIcon\(darkImageAppend())"), for: UIControl.State.normal)
                }
                else
                {
                    addFavoriteButton.setImage(UIImage(named:  "FavoriteAddIcon\(darkImageAppend())"), for: UIControl.State.normal)
                }
            }
        }
    }
    
    @IBAction func addNotificationButtonPressed(_ sender: Any) {
        let newNotification = NSEntityDescription.insertNewObject(forEntityName: "StopNotification", into: CoreDataStack.persistentContainer.viewContext) as! StopNotification
        newNotification.daysOfWeek = try? JSONSerialization.data(withJSONObject: [true, true, true, true, true, true, true], options: JSONSerialization.WritingOptions.sortedKeys)
        newNotification.directionTag = MapState.selectedDirectionTag
        newNotification.stopTag = MapState.selectedStopTag
        newNotification.hour = 12
        newNotification.minute = 0
        newNotification.notificationUUID = UUID().uuidString
        
        CoreDataStack.saveContext()
        
        appDelegate.mainMapViewController?.newStopNotification = newNotification
        appDelegate.mainMapViewController?.performSegue(withIdentifier: "openNewNotificationEditor", sender: self)
    }
    
    @IBAction func stopButtonDoubleTapPressed(_ sender: Any) {
        appDelegate.mainMapViewController?.openNearbyStopViewFromSelectedStop(sender)
    }
}
