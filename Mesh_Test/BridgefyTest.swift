import CoreBluetooth
import BridgefySDK
import SwiftUI

class MyBridgefyDelegate: BridgefyDelegate, ObservableObject {
    private let logManager: LogManager
    
    init(logManager: LogManager) {
        self.logManager = logManager
    }
    
    @Published var isBridgefyStarted = false
    @Published var connectedUsers: Set<UUID> = []
    @Published var localUserId: UUID? = nil
    
    func bridgefyDidFailToStart(with error: BridgefySDK.BridgefyError) {
        DispatchQueue.main.async {
            self.logManager.log("❌ Bridgefy failed to start: \(error.localizedDescription)")
            self.isBridgefyStarted = false
            self.localUserId = nil
        }
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
        DispatchQueue.main.async {
            self.logManager.log("✅ Connected with user: \(userId)")
            self.connectedUsers.insert(userId)
        }
    }
    
    func bridgefyDidDisconnect(from userId: UUID) {
        DispatchQueue.main.async {
            self.logManager.log("Disconnected from user: \(userId)")
            self.connectedUsers.remove(userId)
        }
    }
    
    func bridgefyDidEstablishSecureConnection(with userId: UUID) {
        logManager.log("✅ Secure connection established with: \(userId)")
    }
    
    func bridgefyDidFailToEstablishSecureConnection(with userId: UUID, error: BridgefySDK.BridgefyError) {
        logManager.log("❌ Failed to establish secure connection: \(error.localizedDescription)")
    }
    
    func bridgefyDidSendMessage(with messageId: UUID) {
        DispatchQueue.main.async {
            self.logManager.log("✅ Message sent successfully with ID: \(messageId)")
        }
    }
    
    func bridgefyDidFailSendingMessage(with messageId: UUID, withError error: BridgefySDK.BridgefyError) {
        DispatchQueue.main.async {
            self.logManager.log("❌ Failed to send message: \(error.localizedDescription)")
        }
    }
    
    func bridgefyDidReceiveData(_ data: Data, with messageId: UUID, using transmissionMode: BridgefySDK.TransmissionMode) {
        if let message = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.logManager.log("📩 Received message: \(message)")
                self.logManager.log("Message ID: \(messageId)")
                
                switch transmissionMode {
                case .broadcast(let senderId):
                    self.logManager.log("Broadcast from: \(senderId)")
                case .mesh(let userId):
                    self.logManager.log("Mesh message from: \(userId)")
                case .p2p(userId: let userId):
                    self.logManager.log("P2P message from: \(userId)")
                @unknown default:
                    self.logManager.log("Unknown transmission mode")
                }
            }
        }
    }
    
    func bridgefyDidStart(with userId: UUID) {
        DispatchQueue.main.async {
            self.logManager.log("✅ Bridgefy started successfully with User ID: \(userId)")
            self.isBridgefyStarted = true
            self.localUserId = userId
        }
    }
    
    func bridgefyDidStop() {
        DispatchQueue.main.async {
            self.logManager.log("Bridgefy stopped")
            self.isBridgefyStarted = false
            self.connectedUsers.removeAll()
            self.localUserId = nil
        }
    }
}

var bridgefy: Bridgefy?

class BridgefyManager: ObservableObject {
    private var bridgefyInstance: Bridgefy
    private let delegate: MyBridgefyDelegate
    private let logManager: LogManager
    @Published var isInitialized = false

    init(bridgefyInstance: Bridgefy, delegate: MyBridgefyDelegate, logManager: LogManager) {
        self.bridgefyInstance = bridgefyInstance
        self.delegate = delegate
        self.logManager = logManager
    }

    func startBridgefy(userId: UUID?, propagationProfile: PropagationProfile) {
        logManager.log("Starting Bridgefy with profile: \(propagationProfile)")
        bridgefyInstance.start(withUserId: userId, andPropagationProfile: propagationProfile)
        logManager.log("✅ Start command sent to Bridgefy. Waiting for confirmation...")
        isInitialized = true
    }
    
    func stopBridgefy() {
        bridgefyInstance.stop()
        logManager.log("Bridgefy has been stopped.")
    }

    func destroyBridgefySession() {
        bridgefyInstance.destroySession()
        logManager.log("Bridgefy session has been destroyed.")
    }
    
    func sendData(_ data: Data, transmissionMode: TransmissionMode) {
        guard delegate.isBridgefyStarted else {
            logManager.log("❌ Cannot send data: Bridgefy service is not started")
            return
        }
        
        do {
            logManager.log("Attempting to send message...")
            let messageID = try bridgefyInstance.send(data, using: transmissionMode)
            logManager.log("Message queued with ID: \(messageID)")
            
            switch transmissionMode {
            case .p2p(let userId):
                logManager.log("Sending P2P message to: \(userId)")
            case .broadcast:
                logManager.log("Broadcasting message to all nearby devices")
            case .mesh(let userId):
                logManager.log("Sending mesh message via: \(userId)")
            @unknown default:
                logManager.log("Unknown transmission mode")
            }
        } catch {
            logManager.log("❌ Error sending data: \(error.localizedDescription)")
        }
    }
    
    func handleReceivedMessage(_ handler: @escaping (String, UUID, TransmissionMode) -> Void) {
        // This function can be used to set up custom message handling
        // You can store the handler and call it from the delegate method
        
        // Example usage in your app:
        // bridgefyManager.handleReceivedMessage { message, senderId, mode in
        //     // Handle the message
        // }
    }
    
    func processReceivedData(_ data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
    
    func connectToPeer(_ userId: UUID) {
        logManager.log("Attempting to establish secure connection with: \(userId)")
        bridgefyInstance.establishSecureConnection(with: userId)
    }
    
    func disconnectFromPeer(_ userId: UUID) {
        logManager.log("Disconnecting from peer: \(userId)")
        // Note: Bridgefy doesn't have a direct disconnect method
        // Connections are managed automatically based on proximity
    }
}

class BluetoothManager: NSObject, CBCentralManagerDelegate, ObservableObject {
    @Published var bluetoothState: CBManagerState = .unknown
    private(set) var centralManager: CBCentralManager!
    private let logManager: LogManager
    private var stateCallback: ((CBManagerState) -> Void)?
    
    init(logManager: LogManager) {
        self.logManager = logManager
        super.init()
        
        logManager.log("Initializing Bluetooth Manager...")
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func waitForPoweredOn(completion: @escaping (Bool) -> Void) {
        logManager.log("Checking Bluetooth state: \(centralManager.state.description)")
        
        if centralManager.state == .poweredOn {
            completion(true)
            return
        }
        
        let timeout = DispatchTime.now() + 5.0
        
        func checkState() {
            if centralManager.state == .poweredOn {
                completion(true)
                return
            }
            
            if DispatchTime.now() > timeout {
                logManager.log("Bluetooth state check timed out")
                completion(false)
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkState()
            }
        }
        
        checkState()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.bluetoothState = central.state
            self.logManager.log("Bluetooth state updated: \(central.state.description)")
            
            switch central.state {
            case .poweredOn:
                self.logManager.log("✅ Bluetooth is powered on and ready")
            case .poweredOff:
                self.logManager.log("❌ Bluetooth is powered off")
            case .unauthorized:
                self.logManager.log("❌ Bluetooth permission denied")
            case .resetting:
                self.logManager.log("⚠️ Bluetooth is resetting")
            case .unsupported:
                self.logManager.log("❌ Bluetooth is not supported")
            case .unknown:
                self.logManager.log("⚠️ Bluetooth state is unknown")
            @unknown default:
                self.logManager.log("❌ Unknown Bluetooth state")
            }
        }
    }
}

func initializeBridgefy(logManager: LogManager, delegate: MyBridgefyDelegate) {
    logManager.log("Starting Bridgefy initialization sequence...")
    
    let bluetoothManager = BluetoothManager(logManager: logManager)
    
    bluetoothManager.waitForPoweredOn { isReady in
        guard isReady else {
            logManager.log("❌ Bluetooth failed to initialize. Current state: \(bluetoothManager.centralManager.state.description)")
            return
        }
        
        logManager.log("✅ Bluetooth is ready, proceeding with Bridgefy initialization")
        
        let apiKey = "20f725a8-049f-4896-a118-aa187197d52c"
        
        if let existingBridgefy = bridgefy {
            logManager.log("Cleaning up existing Bridgefy instance...")
            let bridgefyManager = BridgefyManager(
                bridgefyInstance: existingBridgefy,
                delegate: delegate,
                logManager: logManager
            )
            bridgefyManager.stopBridgefy()
            bridgefyManager.destroyBridgefySession()
            bridgefy = nil
        }
        
        do {
            logManager.log("Creating new Bridgefy instance...")
            bridgefy = try Bridgefy(
                withApiKey: apiKey,
                delegate: delegate,
                verboseLogging: true
            )
            
            logManager.log("✅ Bridgefy SDK initialized successfully")
            
            if let bridgefy = bridgefy {
                let bridgefyManager = BridgefyManager(
                    bridgefyInstance: bridgefy,
                    delegate: delegate,
                    logManager: logManager
                )
                
                logManager.log("Starting Bridgefy...")
                let propagationProfile = PropagationProfile.standard
                bridgefyManager.startBridgefy(userId: nil, propagationProfile: propagationProfile)
            }
        } catch {
            logManager.log("❌ Error initializing Bridgefy SDK: \(error.localizedDescription)")
        }
    }
}

extension CBManagerState {
    var description: String {
        switch self {
        case .poweredOn: return "Powered On"
        case .poweredOff: return "Powered Off"
        case .resetting: return "Resetting"
        case .unauthorized: return "Unauthorized"
        case .unknown: return "Unknown"
        case .unsupported: return "Unsupported"
        @unknown default: return "Unknown State"
        }
    }
}
