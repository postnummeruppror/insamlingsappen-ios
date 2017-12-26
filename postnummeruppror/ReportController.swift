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

class ReportController: UIViewController, CLLocationManagerDelegate {

    var locationManager = CLLocationManager()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate


    @IBOutlet weak var accuracyLabel: UILabel!
    

    @IBAction func showAboutDialog(_ sender: Any) {
        
        let alert = UIAlertController(title: "Om postnummeruppror", message: "Vi vill skapa en ny postnummerdatabas fri att använda för alla. Samtidigt vill vi visa för politiker att affärsmodellen för postnummer är förlegad. \nEftersom ursprungskällan till postnummer är skyddad måste vi bygga upp en ny databas från grunden. Vi vill göra det med din hjälp. Genom att rapportera in adressinformation med någon av våra appar kan du bidra till databasen.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapItem: MKMapView!
    @IBOutlet weak var labelIntro: UILabel!
    @IBOutlet weak var postalCode: UITextField!
    @IBOutlet weak var postalTown: UITextField!
    @IBOutlet weak var streetName: UITextField!
    @IBOutlet weak var houseNumber: UITextField!
    @IBOutlet weak var houseName: UITextField!
    
    
    var latitude = 0.0
    var longitude = 0.0
    var accuracy = 0.0
    var altitude = 0.0
    
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
            self.accuracyLabel.text = String(self.accuracy)
            
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
    
    
    
    // Show the popup to the user if we have been deined access
    func showLocationDisabledPopUp() {
        let alertController = UIAlertController(title: "Platsinformation avstängd",
                                                message: "För att detta ska lira behöver vi få information om din plats.",
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
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                  regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // For use when the app is open
        //locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
        
        // If location services is enabled get the users location
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest // You can change the locaiton accuary here.
            locationManager.startUpdatingLocation()
        }
        
        // Default location in central Sweden somewhere
        let initialLocation = CLLocation(latitude: 59.635039, longitude: 14.841073)
        centerMapOnLocation(location: initialLocation)
        
        // Is user registered?
        let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        request.returnsObjectsAsFaults = false
        do {
            let result = try context.fetch(request)
            
            if result.count == 0 {
                // showSettings
                performSegue(withIdentifier: "showSettings", sender: self)
            }
        } catch {
            print("Failed to load user")
        }
        
        // Enable tap outside to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
