//
//  ContentView.swift
//  Mesh_Test
//
//  Created by Djoostin on 13/10/2024.
//

import CoreBluetooth
import BridgefySDK
import SwiftUI

extension Color {
    static let darkBackground = Color(UIColor.systemGray6)
    static let darkElementBackground = Color(UIColor.systemGray5)
    static let darkTextPrimary = Color.white
    static let darkTextSecondary = Color(UIColor.lightGray)
    static let darkAccent = Color.blue
    static let darkGreen = Color.green
    static let darkGrayButton = Color(UIColor.darkGray)
}

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
    
    @Environment(\.colorScheme) var colorScheme

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

        // Customize Picker appearance for dark mode if needed (globally)
        // UISegmentedControl.appearance().selectedSegmentTintColor = UIColor.systemBlue
        // UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        // UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.lightGray], for: .normal)
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.darkBackground : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Image("nexus.png")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .padding(.leading)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bluetooth Hardware")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .darkTextSecondary : .gray)
                            StatusIndicator(
                                isActive: bluetoothManager.bluetoothState == .poweredOn,
                                text: "Status: \(bluetoothManager.bluetoothState.description)",
                                description: "Hardware must be powered on to enable mesh networking",
                                isDarkMode: colorScheme == .dark
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mesh Network Service")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .darkTextSecondary : .gray)
                            StatusIndicator(
                                isActive: bridgefyDelegate.isBridgefyStarted,
                                text: "Status: \(bridgefyDelegate.isBridgefyStarted ? "Online as \(bridgefyDelegate.customDeviceName ?? "Unknown")" : "Offline")",
                                description: "Bridgefy mesh network service status",
                                isDarkMode: colorScheme == .dark
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connected Devices")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .darkTextSecondary : .gray)
                            StatusIndicator(
                                isActive: !bridgefyDelegate.connectedUsers.isEmpty,
                                text: "Peers: \(bridgefyDelegate.connectedUsers.count)",
                                description: "Number of directly connected devices",
                                isDarkMode: colorScheme == .dark
                            )
                        }
                    }
                    .padding(.trailing)
                }
                .padding(.top, 10)
                .padding(.bottom, 10)

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Available Peers")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .darkTextPrimary : .black)
                            Spacer()
                            Button(action: { showingPeerList = true }) {
                                Image(systemName: "person.2")
                                Text("View All")
                            }
                            .foregroundColor(colorScheme == .dark ? .darkAccent : .blue)
                        }
                        .padding(.horizontal)
                        
                        if let selectedPeer = selectedPeer {
                            HStack {
                                Text("Selected Peer:")
                                    .foregroundColor(colorScheme == .dark ? .darkTextSecondary : .gray)
                                Text(bridgefyDelegate.deviceNames[selectedPeer] ?? String(selectedPeer.uuidString.prefix(8)))
                                    .foregroundColor(colorScheme == .dark ? .darkGreen : .green)
                                Spacer()
                                Button(action: { self.selectedPeer = nil }) {
                                    Text("Deselect")
                                        .foregroundColor(colorScheme == .dark ? Color.pink : .red)
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
                    .frame(maxWidth: .infinity)
                    .background(colorScheme == .dark ? Color.darkGrayButton : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isInitializing || bridgefyDelegate.isBridgefyStarted)
                .padding(.horizontal)
                .padding(.top, 10)

                if bridgefyDelegate.isBridgefyStarted {
                    Button(action: {
                        logManager.log("Manually stopping Bridgefy instance...")
                        bridgefy?.stop()
                    }) {
                        Text("Stop Bridgefy")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)
                }

                Picker("Send Mode", selection: $transmissionStrategy) {
                    ForEach(TransmissionStrategy.allCases) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .colorScheme(colorScheme == .dark ? .dark : .light)


                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(zip(logManager.logMessages.indices, logManager.logMessages)), id: \.0) { index, message in
                            Text(message)
                                .padding(.horizontal)
                                .foregroundColor(colorScheme == .dark ? .darkTextSecondary : .black)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color.darkElementBackground.opacity(0.5) : Color.black.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                Spacer()
                
                VStack(spacing: 10) {
                    TextField("Enter Your Device Name", text: $deviceName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(colorScheme == .dark ? Color.darkElementBackground.opacity(0.5) : Color(UIColor.systemGray6))
                        .cornerRadius(8)
                        .foregroundColor(colorScheme == .dark ? .darkTextPrimary : .black)
                        .accentColor(colorScheme == .dark ? .darkAccent : .blue)
                        .padding(.horizontal)
                        .disabled(bridgefyDelegate.isBridgefyStarted || isInitializing)

                    TextField("Enter message", text: $messageText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(colorScheme == .dark ? Color.darkElementBackground.opacity(0.5) : Color(UIColor.systemGray6))
                        .cornerRadius(8)
                        .foregroundColor(colorScheme == .dark ? .darkTextPrimary : .black)
                        .accentColor(colorScheme == .dark ? .darkAccent : .blue)
                        .padding(.horizontal)
                    
                    Button(action: sendMessage) {
                        Text("Send")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSendMessage ? (colorScheme == .dark ? Color.darkGreen.opacity(0.8) : Color.green) : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!canSendMessage)
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingPeerList) {
            PeerListView(
                bridgefyDelegate: bridgefyDelegate,
                selectedPeer: $selectedPeer,
                isPresented: $showingPeerList
            )
            .preferredColorScheme(colorScheme == .dark ? .dark : .light)
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
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundColor(isDarkMode ? .darkTextSecondary : .black)
        }
        .padding(6)
        .background(isDarkMode ? Color.darkElementBackground.opacity(0.3) : Color.white)
        .cornerRadius(15)
        .shadow(color: isDarkMode ? .clear : .gray.opacity(0.5) , radius: isDarkMode ? 0 : 2)
        .help(description)
    }
}

#Preview {
    ContentView().preferredColorScheme(.light)
    ContentView().preferredColorScheme(.dark)
}
