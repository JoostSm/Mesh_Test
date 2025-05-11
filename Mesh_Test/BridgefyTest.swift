import CoreBluetooth
import BridgefySDK
import SwiftUI
import UIKit

class MyBridgefyDelegate: BridgefyDelegate, ObservableObject {
    private let logManager: LogManager
    
    init(logManager: LogManager) {
        self.logManager = logManager
    }
    
    @Published var isBridgefyStarted = false
    @Published var connectedUsers: Set<UUID> = []
    @Published var localUserId: UUID? = nil
    @Published var deviceNames: [UUID: String] = [:]
    @Published var customDeviceName: String? = nil
    
    func bridgefyDidFailToStart(with error: BridgefySDK.BridgefyError) {
        DispatchQueue.main.async {
            self.logManager.log("❌ Bridgefy failed to start: \(error.localizedDescription)")
            self.isBridgefyStarted = false
            self.localUserId = nil
            // self.customDeviceName = nil // Or handle this based on desired UX
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
            // This ensures the new peer gets our name quickly.
            if let localId = self.localUserId, self.customDeviceName != nil {
                self.broadcastOwnDeviceName(localBridgefyId: localId)
            }
        }
    }
    
    func bridgefyDidDisconnect(from userId: UUID) {
        DispatchQueue.main.async {
            self.logManager.log("Disconnected from user: \(userId)")
            self.connectedUsers.remove(userId)
            // deviceNames.removeValue(forKey: userId) // Optionally remove name on disconnect
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
        // Attempt to decode as DeviceNameMessage first
        let decoder = JSONDecoder()
        if let nameMessage = try? decoder.decode(DeviceNameMessage.self, from: data) {
            DispatchQueue.main.async {
                // Store or update the device name
                if nameMessage.senderBridgefyID != self.localUserId {
                    self.deviceNames[nameMessage.senderBridgefyID] = nameMessage.deviceName
                    // Using String() for consistency in logging as well
                    self.logManager.log("ℹ️ Received device name: '\(nameMessage.deviceName)' for ID: \(String(nameMessage.senderBridgefyID.uuidString.prefix(8)))")
                }
            }
            // This was a device name message, so we don't process it as a chat message.
            return
        }

        // If not a DeviceNameMessage, process as a regular chat message
        if let message = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.logManager.log("📩 Received message: \(message)")
                self.logManager.log("Message ID: \(messageId)")
                
                switch transmissionMode {
                case .broadcast(let senderId):
                    // FIX: Explicitly convert Substring to String
                    let senderDisplayName = self.deviceNames[senderId] ?? String(senderId.uuidString.prefix(8))
                    self.logManager.log("Broadcast from: \(senderDisplayName)")
                case .mesh(let userId):
                    // Ensure String conversion here too for consistency
                    let senderDisplayName = self.deviceNames[userId] ?? String(userId.uuidString.prefix(8))
                    self.logManager.log("Mesh message from: \(senderDisplayName)")
                case .p2p(userId: let userId):
                    // Ensure String conversion here too for consistency
                    let senderDisplayName = self.deviceNames[userId] ?? String(userId.uuidString.prefix(8))
                    self.logManager.log("P2P message from: \(senderDisplayName)")
                @unknown default:
                    self.logManager.log("Unknown transmission mode")
                }
            }
        } else {
            self.logManager.log("⚠️ Received data that could not be decoded as DeviceNameMessage or String. Message ID: \(messageId)")
        }
    }
    
    func bridgefyDidStart(with userId: UUID) {
        DispatchQueue.main.async {
            self.logManager.log("✅ Bridgefy started successfully with User ID: \(userId)")
            self.isBridgefyStarted = true
            self.localUserId = userId

            // Now, broadcast our device name using the custom name
            self.broadcastOwnDeviceName(localBridgefyId: userId)
        }
    }
    
    func bridgefyDidStop() {
        DispatchQueue.main.async {
            self.logManager.log("Bridgefy stopped")
            self.isBridgefyStarted = false
            self.localUserId = nil
            self.connectedUsers.removeAll()
            // self.customDeviceName = nil // Reset custom name on stop
            // self.deviceNames.removeAll() // Optionally clear all names on stop
        }
    }

    // MODIFIED: Use customDeviceName if available
    private func broadcastOwnDeviceName(localBridgefyId: UUID) {
        guard let bridgefyInstance = bridgefy else {
            logManager.log("❌ Bridgefy instance not available to broadcast device name.")
            return
        }

        // Use the customDeviceName if set, otherwise fall back to UIDevice.current.name (or handle error)
        guard let nameToBroadcast = self.customDeviceName, !nameToBroadcast.isEmpty else {
            logManager.log("❌ Custom device name not set or empty. Cannot broadcast device name.")
            // Optionally, you could fall back to UIDevice.current.name here if desired:
            // let nameToBroadcast = UIDevice.current.name
            // But for this feature, we require the custom name.
            return
        }
        
        let nameMessagePayload = DeviceNameMessage(senderBridgefyID: localBridgefyId, deviceName: nameToBroadcast)
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(nameMessagePayload)
            _ = try bridgefyInstance.send(data, using: .broadcast(senderId: localBridgefyId))
            logManager.log("📢 Broadcasted own device name: '\(nameToBroadcast)' with ID: \(localBridgefyId.uuidString.prefix(8))")
        } catch {
            logManager.log("❌ Error encoding or sending own device name: \(error.localizedDescription)")
        }
    }
}

struct DeviceNameMessage: Codable {
    let senderBridgefyID: UUID
    let deviceName: String
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
                let peerName = delegate.deviceNames[userId] ?? String(userId.uuidString.prefix(8))
                logManager.log("Sending P2P message to: \(peerName)")
            case .broadcast:
                logManager.log("Broadcasting message to all nearby devices")
            case .mesh(let userId):
                let peerName = delegate.deviceNames[userId] ?? String(userId.uuidString.prefix(8))
                logManager.log("Sending mesh message via: \(peerName)")
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

func initializeBridgefy(deviceName: String, logManager: LogManager, delegate: MyBridgefyDelegate) {
    logManager.log("Starting Bridgefy initialization sequence for device: \(deviceName)...")
    
    // Set the custom device name on the delegate
    // This needs to be done before bridgefy.start() is called so that
    // broadcastOwnDeviceName (called in bridgefyDidStart) has the name.
    DispatchQueue.main.async { // Ensure UI-related properties on delegate are updated on main thread
        delegate.customDeviceName = deviceName
    }

    let bluetoothManager = BluetoothManager(logManager: logManager)
    
    bluetoothManager.waitForPoweredOn { isReady in
        guard isReady else {
            logManager.log("❌ Bluetooth failed to initialize. Current state: \(bluetoothManager.centralManager.state.description)")
            // Consider resetting the customDeviceName on the delegate if init fails
            // DispatchQueue.main.async { delegate.customDeviceName = nil }
            return
        }
        
        logManager.log("✅ Bluetooth is ready, proceeding with Bridgefy initialization")
        
        let apiKey = "20f725a8-049f-4896-a118-aa187197d52c"
        
        if let existingBridgefy = bridgefy {
            logManager.log("Cleaning up existing Bridgefy instance...")
            // Stop and destroy session if already initialized.
            // This also helps if user wants to re-initialize with a new name.
            // Note: The delegate's customDeviceName is already updated above.
            existingBridgefy.stop() // Directly call stop and destroy
            existingBridgefy.destroySession()
            bridgefy = nil // Clear the global instance
            
            // Update delegate state for UI
            DispatchQueue.main.async {
                delegate.isBridgefyStarted = false
                delegate.localUserId = nil
                delegate.connectedUsers.removeAll()
            }
        }
        
        do {
            logManager.log("Creating new Bridgefy instance...")
            // The delegate instance passed here already has customDeviceName set.
            bridgefy = try Bridgefy(
                withApiKey: apiKey,
                delegate: delegate,
                verboseLogging: true
            )
            
            logManager.log("✅ Bridgefy SDK initialized successfully")
            
            if let currentBridgefyInstance = bridgefy {
                // No need to create a new BridgefyManager instance just to call start.
                // We can call start directly on the 'bridgefy' global instance.
                logManager.log("Starting Bridgefy...")
                let propagationProfile = PropagationProfile.standard
                // The delegate (which is 'delegate') will handle bridgefyDidStart
                // and broadcast the name stored in delegate.customDeviceName.
                currentBridgefyInstance.start(withUserId: nil, andPropagationProfile: propagationProfile)
            }
        } catch {
            logManager.log("❌ Error initializing Bridgefy SDK: \(error.localizedDescription)")
            // If SDK init fails, reset the custom name on delegate as Bridgefy won't start with it
            DispatchQueue.main.async {
                delegate.customDeviceName = nil
                // also ensure isBridgefyStarted is false if it was somehow set true before failure
                delegate.isBridgefyStarted = false
            }
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
