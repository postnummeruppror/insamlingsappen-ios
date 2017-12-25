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

import Foundation
import UIKit

class Utils {
    
    // Show simple modal alert
    static func showAlert(view: UIViewController, title: String, message: String, buttontext: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: buttontext, style: UIAlertActionStyle.default, handler: nil))
        view.present(alert, animated: true, completion: nil)
    }
    
    // An alphanumeric string that uniquely identifies a device to postnummeruppror while preserving privacy. Will change if app is deleted/reinstalled.
    static func getUUID() -> String {
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            print("Returning device UUID: " + uuid)
            return uuid
        } else {
            print("Failed getting device UUID. Returning 0.")
            return "0"
        }
    }
}
