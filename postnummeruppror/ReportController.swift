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


    @IBOutlet weak var accuracyLabel: UILabel!
    

    @IBAction func showAboutDialog(_ sender: Any) {
        
        let alert = UIAlertController(title: "Om postnummeruppror", message: "Vi vill skapa en ny postnummerdatabas fri att använda för alla. Samtidigt vill vi visa för politiker att affärsmodellen för postnummer är förlegad. \nEftersom ursprungskällan till postnummer är skyddad måste vi bygga upp en ny databas från grunden. Vi vill göra det med din hjälp. Genom att rapportera in adressinformation med någon av våra appar kan du bidra till databasen.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
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
    
    var latitude = 0.0
    var longitude = 0.0
    var accuracy = 0.0
    var altitude = 0.0
    
    
    fileprivate func validate(_ textField: UITextField) -> (Bool, String?) {
        guard let text = textField.text else {
            return (false, nil)
        }
        
        if textField == postalCode {
            return (text.count == 5, "Fel antal siffror i postnummer.")
        }
        
        if textField == postalTown {
            return (text.count > 1, "Ange en korrekt postort.")
        }
        
        if textField == streetName {
            return (text.count > 3, "Ange en gatuadress.")
        }
        
        return (true, "")
    }
    
    
    
    
    @IBAction func sendReport(_ sender: Any) {
        
        // prepare json data
        let json: [String: Any] = ["applicationVersion": Bundle.main.releaseVersionNumber,
                                   "application": "insamlingsappen-ios",
                                   "accountIdentity": Utils.getUUID(),
                                   "coordinate[provider]": "gps",
                                   "coordinate[accuracy]": self.accuracy,
                                   "coordinate[latitude]": self.latitude,
                                   "coordinate[longitude]": self.longitude,
                                   "coordinate[altitude]": self.altitude,
                                   "postalAddress[postalCode]": postalCode.text ?? "",
                                   "postalAddress[postalTown]": postalTown.text ?? "",
                                   "postalAddress[houseNumber]": houseNumber.text ?? "",
                                   "postalAddress[houseName]": houseName.text ?? "",
                                   ]
        print(json)
        
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        let postURL = URL(string: "https://insamling.postnummeruppror.nu/api/0.0.5/location_sample/create")!
        var postRequest = URLRequest(url: postURL, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 60.0)
        postRequest.httpMethod = "POST"
        postRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let jsonParams = try JSONSerialization.data(withJSONObject: json, options: [])
            postRequest.httpBody = jsonParams
        } catch { print("Error: unable to add parameters to POST request.")}
        
        URLSession.shared.dataTask(with: postRequest, completionHandler: { (data, response, error) -> Void in
            if error != nil { print("POST Request: Communication error: \(error!)") }
            if data != nil {
                do {
                    if let safeData = data{
                        print("Response: \(String(data:safeData, encoding:.utf8))")
                    }
                    if let resultObject = try JSONSerialization.jsonObject(with: data!, options: []) as? NSDictionary {

                        var reportidentity = String(describing: resultObject.value(forKey: "identity")!)

                        DispatchQueue.main.async(execute: {
                            print("Results from POST:\n\(String(describing: resultObject))")
                            
                            let alert = UIAlertController(title: "Tack", message: "Tack för din rapport. (nr. " + reportidentity + ")", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        })
                    }
                    
                } catch {
                    
                    // show messagebox
                    let alert = UIAlertController(title: "Fel", message: "Kunde inte skapa rapport. Försök senare.", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    
                    DispatchQueue.main.async(execute: {
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
    
    
    // If we have been deined access give the user the option to change it
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
    
    
    // Show the popup to the user if we have been denied location
    func showLocationDisabledPopUp() {
        let alertController = UIAlertController(title: "Platsinformation avstängd",
                                                message: "För att detta ska lira behöver vi få information om din plats. Öppna inställningar och tillåt platsinformation när appen används",
                                                preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Avbryt", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let openAction = UIAlertAction(title: "Öppna inställningar", style: .default) { (action) in
            if let url = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        alertController.addAction(openAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    // Zoom to 250 m radius
    let regionRadius: CLLocationDistance = 250
    
    
    //Center map
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                  regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    

    // Set upp OSM tile renderer
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return tileRenderer
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
                // showSettings view
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
        
        // Hide validation message container
        labelValidationResult.isHidden = true
        
        // Start with send button disabled
        sendButton.isEnabled = false
    }

    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        
        // Show send button if no validation message
        self.sendButton.isEnabled = self.labelValidationResult.isHidden
    }
    
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case postalCode:
            checkValid(postalCode, nextField: postalTown)
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





