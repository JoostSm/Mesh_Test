import UIKit
import CoreBluetooth

class AppDelegate: UIResponder, UIApplicationDelegate {
    let logManager = LogManager()
    lazy var bluetoothManager = BluetoothManager(logManager: logManager)
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
}
