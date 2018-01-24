// Copyright 2017, Postnummeruppror.nu
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import MapKit
import CoreLocation
import CoreData

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

class ReportController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    var locationManager = CLLocationManager()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate


    

    @IBAction func showAboutDialog(_ sender: Any) {
        
        // See https://stackoverflow.com/questions/30874386/how-to-correctly-open-url-from-uialertviewcontrollers-handler for hints on handling link opening from alert
        
        let alert = UIAlertController(title: "Om postnummeruppror", message: "Vi vill skapa en ny postnummerdatabas fri att använda för alla. Samtidigt vill vi visa för politiker att affärsmodellen för postnummer är förlegad. \nEftersom ursprungskällan till postnummer är skyddad måste vi bygga upp en ny databas från grunden. Vi vill göra det med din hjälp. Genom att rapportera in adressinformation med någon av våra appar kan du bidra till databasen.\n(v " + String(describing: Bundle.main.releaseVersionNumber!) + "b" + String(describing: Bundle.main.buildVersionNumber!) + ")" , preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        alert.addAction(UIAlertAction(title: "Läs mer", style: UIAlertActionStyle.default, handler: {
            (action) in
            UIApplication.shared.open(URL(string: "https://postnummeruppror.nu/")!, options: [:], completionHandler: nil)
            NSLog("Opening link")
        }))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    @IBOutlet weak var mapView: MKMapView!
    var tileRenderer: MKTileOverlayRenderer!
    @IBOutlet weak var labelIntro: UILabel!
    @IBOutlet weak var postalCode: UITextField!
    @IBOutlet weak var postalTown: UITextField!
    @IBOutlet weak var streetName: UITextField!
    @IBOutlet weak var houseNumber: UITextField!
    @IBOutlet weak var houseName: UITextField!
    @IBOutlet weak var labelValidationResult: UILabel!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var accuracyLabel: UILabel!
    
    
    var latitude = 0.0
    var longitude = 0.0
    var accuracy = 0.0
    var altitude = 0.0
    
    
    @IBAction func clearForm(_ sender: Any) {
        postalTown.text = ""
        postalCode.text = ""
        streetName.text = ""
        houseNumber.text = ""
        houseName.text = ""
    }
    
    
    fileprivate func validate(_ textField: UITextField) -> (Bool, String?) {
        guard let text = textField.text else {
            return (false, nil)
        }
        
        if textField == postalCode {
            return (text.count == 5, "Fel antal siffror i postnummer")
        }
        
        if textField == postalTown {
            return (text.count > 1, "Ange en postort")
        }
        
        if textField == streetName {
            return (text.count > 3, "Ange ett gatunamn")
        }
        
        if textField == houseNumber {
            return (text.count > 0, "Ange gatunummer")
        }
        
        return (true, "")
    }

    struct Coordinate: Codable {
        let provider: String
        let accuracy: Double
        let latitude: Double
        let longitude: Double
        let altitude: Double
    }
    
    struct PostalAddress: Codable {
        let postalCode: String
        let postalTown: String
        let streetName: String
        let houseNumber: String
        let houseName: String
    }
    
    struct Report: Codable {
        let applicationVersion: String
        let application: String
        let accountIdentity: String
        let coordinate: Coordinate
        let postalAddress: PostalAddress
    }
    
    
    @IBAction func sendReport(_ sender: Any) {
        
        // Show modal spinner while sending data
        DispatchQueue.main.async { [unowned self] in
            LoadingOverlay.shared.showOverlay(view: UIApplication.shared.keyWindow!)
        }
        
        // Prepare data
        let coordinate = Coordinate(provider: "gps",
                                    accuracy: self.accuracy,
                                    latitude: self.latitude,
                                    longitude: self.longitude,
                                    altitude: self.altitude)
        
        let postalAddress = PostalAddress(postalCode: postalCode.text ?? "",
                                          postalTown: postalTown.text ?? "",
                                          streetName: streetName.text ?? "",
                                          houseNumber: houseNumber.text ?? "",
                                          houseName: houseName.text ?? "")
        
        let report = Report(
            applicationVersion: Bundle.main.releaseVersionNumber! + "b" + Bundle.main.buildVersionNumber!,
            application: "insamlingsappen-ios",
            accountIdentity: Utils.getUUID(),
            coordinate: coordinate,
            postalAddress: postalAddress
        )
        
        let jsonEncoder = JSONEncoder()
        let jsonData = try? jsonEncoder.encode(report)
        
        // Debug print it
        let jsonstr = String(data: jsonData!, encoding: .utf8)
        print(jsonstr)
        
        // Post it
        let postURL = URL(string: "https://insamling.postnummeruppror.nu/api/0.0.5/location_sample/create")!
        var postRequest = URLRequest(url: postURL, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 60.0)
        postRequest.httpMethod = "POST"
        postRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        postRequest.httpBody = jsonData
        
        URLSession.shared.dataTask(with: postRequest, completionHandler: { (data, response, error) -> Void in
            if error != nil { print("POST Request: Communication error: \(error!)") }
            
            if data != nil {
                do {
                    
                    //Print response
                    print(NSString(data: data!, encoding: String.Encoding.utf8.rawValue))
                    
                    if let safeData = data{
                        print("Response: \(String(describing: String(data:safeData, encoding:.utf8)))")
                    }
                    if let resultObject = try JSONSerialization.jsonObject(with: data!, options: []) as? NSDictionary {

                        var reportidentity = String(describing: resultObject.value(forKey: "identity")!)

                        DispatchQueue.main.async(execute: {
                            
                            // Hide spinner
                            LoadingOverlay.shared.hideOverlayView()
                            
                            print("Results from POST:\n\(String(describing: resultObject))")
                            
                            // Show thank you alert
                            let alert = UIAlertController(title: "Tack", message: "Tack för din rapport. (nr. " + reportidentity + ")", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        })
                    }
                    
                } catch {
                    
                    DispatchQueue.main.async(execute: {
                        
                    // Hide spinner
                    LoadingOverlay.shared.hideOverlayView()
                    
                    // show error alert
                    let alert = UIAlertController(title: "Fel", message: "Kunde inte skapa rapport. Försök senare.", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    
                        print("Unable to parse JSON response")
                    })
                    
                }
            } else {
                DispatchQueue.main.async(execute: {
                    print("Received empty response.")
                })
            }
        }).resume()
    }
    
    
    // Print out the location to the console
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print(location.coordinate)
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.accuracy = location.horizontalAccuracy
            self.altitude = location.altitude
            
            // Update accuracy label above map
            self.accuracyLabel.text = String(Int(self.accuracy))
            
            if self.accuracy > 50.0 {
                self.accuracyLabel.textColor = UIColor.red
            } else {
                self.accuracyLabel.textColor = UIColor.black
            }
            
            centerMapOnLocation(location: location)
        }
    }
    
    
    // If we have been denied access give the user the option to change it
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if(status == CLAuthorizationStatus.denied) {
            showLocationDisabledPopUp()
        }
    }
    
    
    // Switch to OSM tile layer
    func setupTileRenderer() {
        let template = "https://a.tile.openstreetmap.se/osm/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        self.mapView.add(overlay, level: .aboveLabels)
        tileRenderer = MKTileOverlayRenderer(tileOverlay: overlay)
    }
    
    
    // Set upp OSM tile renderer
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return tileRenderer
    }
    
    // Show popup to the user if we have been denied location
    func showLocationDisabledPopUp() {
        let alertController = UIAlertController(title: "Platsinformation avstängd",
                                                message: "För att detta ska lira behöver vi få information om din plats. Öppna inställningar och tillåt platsinformation när appen används",
                                                preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let openAction = UIAlertAction(title: "Inställningar", style: .default) { (action) in
            if let url = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        alertController.addAction(openAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    // Zoom to 250 m radius
    let regionRadius: CLLocationDistance = 250
    
    
    // Center map
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTileRenderer()
        
        // Ask for location when app is in use
        locationManager.requestWhenInUseAuthorization()
        
        // If location services is enabled get the user's location
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        // Start with default location in central Stockholm somewhere
        let initialLocation = CLLocation(latitude: 59.342944, longitude: 18.083945)
        centerMapOnLocation(location: initialLocation)
        mapView.delegate = self
        
        // Is user registered?
        let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        request.returnsObjectsAsFaults = false
        do {
            let result = try context.fetch(request)
            
            if result.count == 0 {
                // show sSettings view
                performSegue(withIdentifier: "showSettings", sender: self)
            }
        } catch {
            print("Failed to load user")
        }
        
        // Enable tap outside to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        // Set text field delegate
        postalCode.delegate = self
        postalTown.delegate = self
        streetName.delegate = self
        houseNumber.delegate = self
        houseName.delegate = self
        
        // Hide validation message container
        labelValidationResult.isHidden = true
        
        // Start with send button disabled
        sendButton.isEnabled = false
    }

    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func isReadyToSubmit() -> Bool {
        let result = (self.postalCode.text!.count == 5 && self.postalTown.text!.count > 1 && self.streetName.text!.count > 3 && self.houseNumber.text!.count > 0)
        return result
        
    }
}



extension ReportController: UITextFieldDelegate {
    
    func checkValid(_ textField: UITextField, nextField: UITextField) {
        let (valid, message) = validate(textField)
        if valid {
            nextField.becomeFirstResponder()
        } else {
            self.labelValidationResult.text = message
        }
        
        // Toggle validation message
        UIView.animate(withDuration: 0.25, animations: {
            self.labelValidationResult.isHidden = valid
        })
    }
    
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        // Check fields using the numeric keyboard here
        if(textField == postalCode || textField == houseNumber) {
            checkValid(textField, nextField: textField)
        }
        
        // Show send button if form is ready for submit
        self.sendButton.isEnabled = isReadyToSubmit()
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case postalTown:
            checkValid(postalTown, nextField: streetName)
        case streetName:
            checkValid(streetName, nextField: houseNumber)
        case houseNumber:
            houseName.becomeFirstResponder()
        default:
            postalCode.resignFirstResponder()
        }
        
        return true
    }
}


// Show modal while data being sent to server.
// https://stackoverflow.com/questions/27960556/loading-an-overlay-when-running-long-tasks-in-ios

public class LoadingOverlay{
    
    var overlayView = UIView()
    var activityIndicator = UIActivityIndicatorView()
    var bgView = UIView()
    
    class var shared: LoadingOverlay {
        struct Static {
            static let instance: LoadingOverlay = LoadingOverlay()
        }
        return Static.instance
    }
    
    public func showOverlay(view: UIView) {
        
        bgView.frame = view.frame
        bgView.backgroundColor = UIColor.gray
        bgView.addSubview(overlayView)
        bgView.autoresizingMask = [.flexibleLeftMargin,.flexibleTopMargin,.flexibleRightMargin,.flexibleBottomMargin,.flexibleHeight, .flexibleWidth]
        
        overlayView.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        overlayView.center = view.center
        overlayView.autoresizingMask = [.flexibleLeftMargin,.flexibleTopMargin,.flexibleRightMargin,.flexibleBottomMargin]
        overlayView.backgroundColor = UIColor.white
        overlayView.clipsToBounds = true
        overlayView.layer.cornerRadius = 10
        
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        activityIndicator.activityIndicatorViewStyle = .gray
        activityIndicator.center = CGPoint(x: overlayView.bounds.width / 2, y: overlayView.bounds.height / 2)
        
        overlayView.addSubview(activityIndicator)
        view.addSubview(bgView)
        self.activityIndicator.startAnimating()
        
    }
    
    public func hideOverlayView() {
        activityIndicator.stopAnimating()
        bgView.removeFromSuperview()
    }
}
