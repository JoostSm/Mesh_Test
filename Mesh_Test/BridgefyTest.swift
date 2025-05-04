import CoreBluetooth
import BridgefySDK
import SwiftUI

// Shared instance of LogManager
let logManager = LogManager()

var bridgefy: Bridgefy?

// Implementing the BridgefyDelegate protocol
class MyBridgefyDelegate: BridgefyDelegate {
    func bridgefyDidFailToStart(with error: BridgefySDK.BridgefyError) {
        logManager.log("❌ Bridgefy failed to start: \(error.localizedDescription)")
    }
    
    func bridgefyDidFailToStop(with error: BridgefySDK.BridgefyError) {
        logManager.log("❌ Bridgefy failed to stop: \(error.localizedDescription)")
    }
    
    func bridgefyDidDestroySession() {
        logManager.log("Session destroyed successfully")
    }
    
    func bridgefyDidFailToDestroySession(with error: BridgefySDK.BridgefyError) {
        logManager.log("❌ Failed to destroy session: \(error.localizedDescription)")
    }
    
    func bridgefyDidConnect(with userId: UUID) {
        logManager.log("✅ Connected with user: \(userId)")
    }
    
    func bridgefyDidDisconnect(from userId: UUID) {
        logManager.log("Disconnected from user: \(userId)")
    }
    
    func bridgefyDidEstablishSecureConnection(with userId: UUID) {
        logManager.log("✅ Secure connection established with: \(userId)")
    }
    
    func bridgefyDidFailToEstablishSecureConnection(with userId: UUID, error: BridgefySDK.BridgefyError) {
        logManager.log("❌ Failed to establish secure connection: \(error.localizedDescription)")
    }
    
    func bridgefyDidSendMessage(with messageId: UUID) {
        
    }
    
    func bridgefyDidFailSendingMessage(with messageId: UUID, withError error: BridgefySDK.BridgefyError) {
        
    }
    
    func bridgefyDidReceiveData(_ data: Data, with messageId: UUID, using transmissionMode: BridgefySDK.TransmissionMode) {
        if let message = String(data: data, encoding: .utf8) {
            logManager.log("Received message: \(message)")
            logManager.log("Message ID: \(messageId)")
            logManager.log("Transmission Mode: \(transmissionMode)")
            
            // Handle different transmission modes
            switch transmissionMode {
            case .broadcast(let senderId):
                logManager.log("Broadcast message from sender: \(senderId)")
            case .mesh(let userId):
                logManager.log("Direct mesh message from user: \(userId)")
            case .p2p(userId: let userId):
                logManager.log("P2P message from user: \(userId)")
            @unknown default:
                logManager.log("Unknown transmission mode")
            }
        }
    }
    
    // Property to track Bridgefy start status
    @Published var isBridgefyStarted = false
    
    // Delegate method when Bridgefy starts
    func bridgefyDidStart(with userId: UUID) {
        logManager.log("✅ Bridgefy started with User ID: \(userId)")
        isBridgefyStarted = true
    }
    
    func bridgefyDidStop() {
        logManager.log("Bridgefy stopped")
        isBridgefyStarted = false
    }
}

// Separate class to handle Bridgefy management
class BridgefyManager {
    private var bridgefyInstance: Bridgefy
    private let delegate: MyBridgefyDelegate

    // Initializer accepts the Bridgefy instance and delegate
    init(bridgefyInstance: Bridgefy, delegate: MyBridgefyDelegate) {
        self.bridgefyInstance = bridgefyInstance
        self.delegate = delegate
    }

    // Start Bridgefy with userId and propagation profile
    func startBridgefy(userId: UUID?, propagationProfile: PropagationProfile) {
        bridgefyInstance.start(withUserId: userId, andPropagationProfile: propagationProfile)
        logManager.log("Attempting to start Bridgefy with UserId: \(String(describing: userId)) and Propagation Profile: \(propagationProfile)")
    }

    // Stop Bridgefy
    func stopBridgefy() {
        bridgefyInstance.stop()
        logManager.log("Bridgefy has been stopped.")
    }

    // Destroy the Bridgefy session
    func destroyBridgefySession() {
        bridgefyInstance.destroySession()
        logManager.log("Bridgefy session has been destroyed.")
    }
    
    // Method to send data
    func sendData(_ data: Data, transmissionMode: TransmissionMode, targetUserId: UUID? = nil) {
        guard delegate.isBridgefyStarted else {
            logManager.log("Cannot send data: Bridgefy service is not started.")
            return
        }
        
        do {
            let messageID: UUID
            
            if let userId = targetUserId {
                messageID = try bridgefyInstance.send(data, using: .mesh(userId: userId))
                logManager.log("Data sent to user \(userId) with Message ID: \(messageID)")
            } else {
                messageID = try bridgefyInstance.send(data, using: transmissionMode)
                logManager.log("Data sent successfully with Message ID: \(messageID)")
            }
            
        } catch {
            logManager.log("Error sending data: \(error.localizedDescription)")
        }
    }
    
    // Message handling function
    func handleReceivedMessage(_ handler: @escaping (String, UUID, TransmissionMode) -> Void) {
        // This function can be used to set up custom message handling
        // You can store the handler and call it from the delegate method
        
        // Example usage in your app:
        // bridgefyManager.handleReceivedMessage { message, senderId, mode in
        //     // Handle the message
        // }
    }
    
    // Function to process received data
    func processReceivedData(_ data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
}

// BluetoothManager class
class BluetoothManager: NSObject, CBCentralManagerDelegate, ObservableObject {
    @Published var bluetoothState: CBManagerState = .unknown
    var centralManager: CBCentralManager!
    
    override init() {
        super.init()
        // Initialize on the main queue
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.bluetoothState = central.state
            switch central.state {
            case .poweredOn:
                logManager.log("Bluetooth is powered on and ready")
            case .poweredOff:
                logManager.log("Bluetooth is powered off")
            case .unauthorized:
                logManager.log("Bluetooth permission denied")
            case .resetting:
                logManager.log("Bluetooth is resetting")
            case .unsupported:
                logManager.log("Bluetooth is not supported")
            case .unknown:
                logManager.log("Bluetooth state is unknown")
            @unknown default:
                logManager.log("Unknown Bluetooth state")
            }
        }
    }
}

// Function to initialize Bridgefy and use BridgefyManager
func initializeBridgefy() {
    logManager.log("Starting Bridgefy initialization...")
    
    // Check Bluetooth state first
    guard let centralManager = BluetoothManager().centralManager else {
        logManager.log("❌ Failed to initialize Bluetooth manager")
        return
    }
    
    if centralManager.state != .poweredOn {
        logManager.log("❌ Bluetooth is not powered on. Current state: \(centralManager.state)")
        return
    }
    
    let apiKey = "20f725a8-049f-4896-a118-aa187197d52c"
    let delegate = MyBridgefyDelegate()
    
    // Stop and destroy existing Bridgefy instance if any
    if let existingBridgefy = bridgefy {
        logManager.log("Cleaning up existing Bridgefy instance...")
        let bridgefyManager = BridgefyManager(bridgefyInstance: existingBridgefy, delegate: delegate)
        bridgefyManager.stopBridgefy()
        bridgefyManager.destroyBridgefySession()
        bridgefy = nil
    }

    do {
        logManager.log("Creating new Bridgefy instance...")
        // Create a new Bridgefy instance
        bridgefy = try Bridgefy(withApiKey: apiKey,
                               delegate: delegate,
                               verboseLogging: true)
        
        logManager.log("✅ Bridgefy SDK initialized successfully")
        
        // Start Bridgefy
        if let bridgefy = bridgefy {
            let bridgefyManager = BridgefyManager(bridgefyInstance: bridgefy, delegate: delegate)
            
            logManager.log("Starting Bridgefy...")
            // Start Bridgefy with new User ID and propagation profile
            let propagationProfile = PropagationProfile.standard
            bridgefyManager.startBridgefy(userId: nil, propagationProfile: propagationProfile)
        }

    } catch {
        logManager.log("❌ Error initializing Bridgefy SDK: \(error.localizedDescription)")
    }
}
