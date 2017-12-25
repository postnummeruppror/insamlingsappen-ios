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
import CoreData

class ViewController: UIViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    struct defaultsKeys {
        static let deviceUUID = "0"
    }
    
    var loadedUser = false
    
    struct SaveUserResult: Decodable {
        let success: Bool
    }
    
    struct User: Codable {
        var identity: String
        var acceptingCcZero: Bool
        var firstName: String
        var lastName: String
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if user data already exists - if so load it into the fields
        let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        request.returnsObjectsAsFaults = false
        do {
            let result = try context.fetch(request)
            
            if result.count > 0 {
                let user = result.first as! NSManagedObject
                emailAddress.text = user.value(forKey: "email") as? String
                firstName.text = user.value(forKey: "firstName") as? String
                lastName.text = user.value(forKey: "lastName") as? String
                
                // Disable accept toggle
                acceptTerms.setOn(true, animated: true)
                acceptTerms.isUserInteractionEnabled = false
                saveBtn.isEnabled = true
                
                self.loadedUser = true
            }
        } catch {
            print("Failed getting stored user data")
        }
    }

    @IBAction func accept(_ sender: Any) {
        saveBtn.isEnabled = !saveBtn.isEnabled
    }
    
    @IBOutlet weak var saveBtn: UIButton!
    
    @IBOutlet weak var acceptTerms: UISwitch!
    
    @IBOutlet weak var emailAddress: UITextField!
    
    @IBOutlet weak var firstName: UITextField!
    
    func moveOn() {
        print("Moving on")
        navigationController?.popViewController(animated: true)
    }

    func saveUserData() {
        print("Saving user data")
        
        let context = appDelegate.persistentContainer.viewContext
        
        // Delete all existing user data
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        
        do {
            try context.execute(request)
        } catch {
            print("Error in deleting previous User data")
        }
        
        // Create new user object
        let entity = NSEntityDescription.entity(forEntityName: "User", in: context)
        let newUser = NSManagedObject(entity: entity!, insertInto: context)
        
        newUser.setValue(self.firstName.text, forKey: "firstName")
        newUser.setValue(self.lastName.text, forKey: "lastName")
        newUser.setValue(self.emailAddress.text, forKey: "email")
        newUser.setValue(Utils.getUUID(), forKey: "identity")
        newUser.setValue(Date(), forKey: "updatedAt")
        
        do {
            try context.save()
            
            DispatchQueue.main.async(){
                self.moveOn()
            }            
        } catch {
            print("Failed saving user")
        }
    }
    

    
    
    
    @IBAction func saveUser(_ sender: Any) {
        
        let identifier = Utils.getUUID()
        
        // Prepare data for account creation
        let json: [String: Any] = ["identity": identifier,
                                   "acceptingCcZero": true,
                                   "firstName": firstName.text!,
                                   "lastName": lastName.text!]
        
        //let jsonData = try? JSONSerialization.data(withJSONObject: json)
        let postURL = URL(string: "https://insamling.postnummeruppror.nu/api/0.0.5/account/set")!
        var postRequest = URLRequest(url: postURL, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 60.0)
        
        postRequest.httpMethod = "POST"
        postRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let jsonParams = try JSONSerialization.data(withJSONObject: json, options: [])
            postRequest.httpBody = jsonParams
        } catch { print("Error: unable to add parameters to POST request.")}
        
        
        URLSession.shared.dataTask(with: postRequest, completionHandler: { (data, response, error) -> Void in
            
            if error != nil {
                
                print("POST Request: Communication error: \(error!)")
                
                DispatchQueue.main.async(execute: {
                    Utils.showAlert(view: self, title: "Något gick fel", message: "Kunde inte spara dina användaruppgifter. Försök senare.", buttontext: "OK")
                })
            }
            
            
            
            if data != nil {
                do {
                    
                    if let safeData = data{
                        print("Response: \(String(describing: String(data:safeData, encoding:.utf8)))")
                    }
                    
                    let resultObject = try JSONSerialization.jsonObject(with: data!, options: [])
                    
                    DispatchQueue.main.async(execute: {
                        print("Results from POST:\n\(resultObject)")
                        
                        // Validate that account was created
                        let saveResult = try? JSONDecoder().decode(SaveUserResult.self, from: data!)
                        
                        if (saveResult?.success)! {
                            self.saveUserData()
                        } else {
                            Utils.showAlert(view: self, title: "Något gick fel", message: "Kunde inte spara dina användaruppgifter. Försök senare.", buttontext: "OK")
                        }
                    })
                } catch {
                    DispatchQueue.main.async(execute: {
                        Utils.showAlert(view: self, title: "Fel vid skapa konto", message: "Kunde inte spara dina användaruppgifter. Försök senare.", buttontext: "OK")
                        print("Unable to parse JSON response")
                    })
                }
            } else {
                DispatchQueue.main.async(execute: {
                    print("Received empty response for account creation.")
                })
            }
        }).resume()
        
    }    
    
    @IBOutlet weak var lastName: UITextField!
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
