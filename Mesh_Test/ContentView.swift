//
//  ContentView.swift
//  Mesh_Test
//
//  Created by Djoostin on 13/10/2024.
//

import CoreBluetooth
import BridgefySDK
import SwiftUI

struct ContentView: View {
    @StateObject private var logManager = LogManager()
    @StateObject private var bluetoothManager: BluetoothManager
    @StateObject private var bridgefyDelegate: MyBridgefyDelegate
    @State private var messageText = ""
    @State private var isInitializing = false
    @State private var selectedPeer: UUID?
    @State private var showingPeerList = false
    @State private var deviceName: String = ""
    @State private var showingNameErrorAlert: Bool = false
    
    enum TransmissionStrategy: String, CaseIterable, Identifiable {
        case standard = "Auto (P2P/Broadcast)"
        case meshToPeer = "Mesh (to Selected Peer)"
        var id: String { self.rawValue }
    }
    @State private var transmissionStrategy: TransmissionStrategy = .standard
    
    init() {
        let sharedLogManager = LogManager()
        _logManager = StateObject(wrappedValue: sharedLogManager)
        _bluetoothManager = StateObject(wrappedValue: BluetoothManager(logManager: sharedLogManager))
        _bridgefyDelegate = StateObject(wrappedValue: MyBridgefyDelegate(logManager: sharedLogManager))
    }
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Mesh Network Setup")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextField("Enter Your Device Name", text: $deviceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .disabled(bridgefyDelegate.isBridgefyStarted || isInitializing)

                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bluetooth Hardware")
                                .font(.caption)
                                .foregroundColor(.gray)
                            StatusIndicator(
                                isActive: bluetoothManager.bluetoothState == .poweredOn,
                                text: "Status: \(bluetoothManager.bluetoothState.description)",
                                description: "Hardware must be powered on to enable mesh networking"
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mesh Network Service")
                                .font(.caption)
                                .foregroundColor(.gray)
                            StatusIndicator(
                                isActive: bridgefyDelegate.isBridgefyStarted,
                                text: "Status: \(bridgefyDelegate.isBridgefyStarted ? "Connected as \(bridgefyDelegate.customDeviceName ?? "Unknown")" : "Disconnected")",
                                description: "Bridgefy mesh network service status"
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connected Devices")
                                .font(.caption)
                                .foregroundColor(.gray)
                            StatusIndicator(
                                isActive: !bridgefyDelegate.connectedUsers.isEmpty,
                                text: "Active peers: \(bridgefyDelegate.connectedUsers.count)",
                                description: "Number of directly connected devices"
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 10)
                .background(Color.white)
                
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Available Peers")
                                .font(.headline)
                            Spacer()
                            Button(action: { showingPeerList = true }) {
                                Image(systemName: "person.2")
                                Text("Connect")
                            }
                            .disabled(!bridgefyDelegate.isBridgefyStarted)
                        }
                        .padding(.horizontal)
                        
                        if let selectedPeer = selectedPeer {
                            HStack {
                                Text("Connected to:")
                                    .foregroundColor(.gray)
                                Text(bridgefyDelegate.deviceNames[selectedPeer] ?? String(selectedPeer.uuidString.prefix(8)))
                                    .foregroundColor(.green)
                                Spacer()
                                Button(action: { self.selectedPeer = nil }) {
                                    Text("Disconnect")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 10)
                }
                
                Button(action: {
                    if deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showingNameErrorAlert = true
                    } else {
                        isInitializing = true
                        initializeBridgefy(deviceName: deviceName, logManager: logManager, delegate: bridgefyDelegate)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            isInitializing = false
                        }
                    }
                }) {
                    HStack {
                        Text(isInitializing ? "Initializing..." : (bridgefyDelegate.isBridgefyStarted ? "Re-initialize Bridgefy" : "Initialize Bridgefy"))
                        if isInitializing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isInitializing || bridgefyDelegate.isBridgefyStarted)
                .padding(.top, 20)

                Picker("Send Mode", selection: $transmissionStrategy) {
                    ForEach(TransmissionStrategy.allCases) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(zip(logManager.logMessages.indices, logManager.logMessages)), id: \.0) { index, message in
                            Text(message)
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                Spacer()
                
                VStack(spacing: 10) {
                    TextField("Enter message", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button(action: sendMessage) {
                        Text("Send")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSendMessage ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!canSendMessage)
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
                .background(Color.white)
                .shadow(radius: 5, y: -5)
            }
        }
        .sheet(isPresented: $showingPeerList) {
            PeerListView(
                bridgefyDelegate: bridgefyDelegate,
                selectedPeer: $selectedPeer,
                isPresented: $showingPeerList
            )
        }
        .alert("Device Name Required", isPresented: $showingNameErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a device name before initializing.")
        }
    }
    
    private var canSendMessage: Bool {
        guard !messageText.isEmpty && bridgefyDelegate.isBridgefyStarted else { return false }
        
        switch transmissionStrategy {
        case .standard:
            return true
        case .meshToPeer:
            return selectedPeer != nil
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty, let data = messageText.data(using: .utf8) else {
            logManager.log("❌ Invalid message")
            return
        }
        
        guard let bridgefy = bridgefy else {
            logManager.log("❌ Bridgefy instance not available")
            return
        }
        
        let bridgefyManager = BridgefyManager(
            bridgefyInstance: bridgefy,
            delegate: bridgefyDelegate,
            logManager: logManager
        )
        
        let finalTransmissionMode: TransmissionMode?
        
        switch transmissionStrategy {
        case .standard:
            if let peer = selectedPeer {
                let peerDisplayName = bridgefyDelegate.deviceNames[peer] ?? String(peer.uuidString.prefix(8))
                finalTransmissionMode = .p2p(userId: peer)
                logManager.log("Sending P2P message to: \(peerDisplayName)")
            } else {
                if let localId = bridgefyDelegate.localUserId {
                    finalTransmissionMode = .broadcast(senderId: localId)
                    logManager.log("Broadcasting message using Standard strategy with local ID: \(localId)")
                } else {
                    logManager.log("⚠️ localUserId is nil, falling back to new UUID for broadcast senderId.")
                    finalTransmissionMode = .broadcast(senderId: UUID())
                }
            }
        case .meshToPeer:
            if let peer = selectedPeer {
                let peerDisplayName = bridgefyDelegate.deviceNames[peer] ?? String(peer.uuidString.prefix(8))
                finalTransmissionMode = .mesh(userId: peer)
                logManager.log("Sending Mesh message to selected peer: \(peerDisplayName)")
            } else {
                logManager.log("❌ Cannot send Mesh message: No peer selected.")
                finalTransmissionMode = nil
            }
        }
        
        if let mode = finalTransmissionMode {
            bridgefyManager.sendData(data, transmissionMode: mode)
            messageText = ""
        } else {
            logManager.log("❌ Message not sent due to configuration.")
        }
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    let text: String
    let description: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
        }
        .padding(6)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 2)
        .help(description)
    }
}

#Preview {
    let logManager = LogManager()
    let bluetoothManager = BluetoothManager(logManager: logManager)
    let bridgefyDelegate = MyBridgefyDelegate(logManager: logManager)
    return ContentView()
}
