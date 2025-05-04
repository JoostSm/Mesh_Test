import UIKit
import CoreBluetooth

class AppDelegate: UIResponder, UIApplicationDelegate {
    let bluetoothManager = BluetoothManager()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
}
