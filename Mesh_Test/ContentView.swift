//
//  ContentView.swift
//  Mesh_Test
//
//  Created by Djoostin on 13/10/2024.
//

import CoreBluetooth
import SwiftUI

struct ContentView: View {
    @StateObject private var logManager = LogManager()
    @StateObject private var bluetoothManager: BluetoothManager
    @StateObject private var bridgefyDelegate: MyBridgefyDelegate
    @State private var messageText = ""
    @State private var isInitializing = false
    
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
                // Status indicators
                HStack(spacing: 10) {
                    // Bluetooth status
                    StatusIndicator(
                        isActive: bluetoothManager.bluetoothState == .poweredOn,
                        text: "Bluetooth: \(bluetoothManager.bluetoothState.description)"
                    )
                    
                    // Bridgefy status
                    StatusIndicator(
                        isActive: bridgefyDelegate.isBridgefyStarted,
                        text: "Bridgefy: \(bridgefyDelegate.isBridgefyStarted ? "Connected" : "Disconnected")"
                    )
                }
                .padding(.top, 10)
                
                // Initialize button
                Button(action: {
                    isInitializing = true
                    initializeBridgefy(logManager: logManager, delegate: bridgefyDelegate)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        isInitializing = false
                    }
                }) {
                    HStack {
                        Text(isInitializing ? "Initializing..." : "Initialize Bridgefy")
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
                .disabled(isInitializing)
                .padding(.top, 20)
                
                // Log messages
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
                
                // Message input and send button
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
    }
    
    private var canSendMessage: Bool {
        !messageText.isEmpty && bridgefyDelegate.isBridgefyStarted
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty, let data = messageText.data(using: .utf8) else {
            logManager.log("❌ Invalid message")
            return
        }
        
        guard bridgefyDelegate.isBridgefyStarted else {
            logManager.log("❌ Bridgefy is not started")
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
        
        logManager.log("Attempting to send message: \(messageText)")
        bridgefyManager.sendData(
            data,
            transmissionMode: .broadcast(senderId: UUID())
        )
        
        messageText = ""
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    let text: String
    
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
    }
}

#Preview {
    let logManager = LogManager()
    let bluetoothManager = BluetoothManager(logManager: logManager)
    let bridgefyDelegate = MyBridgefyDelegate(logManager: logManager)
    return ContentView()
}
