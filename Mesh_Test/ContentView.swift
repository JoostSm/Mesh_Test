//
//  ContentView.swift
//  Mesh_Test
//
//  Created by Djoostin on 13/10/2024.
//

import CoreBluetooth
import SwiftUI

// ADD: LogManager to handle log messages
class LogManager: ObservableObject {
    @Published var logMessages: [String] = []
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages.append(message)
        }
    }
}

struct ContentView: View {
    @StateObject private var logManager = LogManager()
    @State private var messageText = ""
    @State private var isInitializing = false
    
    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Nexus logo
                HStack {
                    Image("nexus.png")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(.top, 15)
                        .padding(.leading, 15)
                    Spacer()
                }
                
                // Initialize Bridgefy Button
                Button(action: {
                    isInitializing = true
                    initializeBridgefy()
                    
                    // Reset initializing state after timeout
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
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(logManager.logMessages, id: \.self) { message in
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
                
                // Message input and send button at bottom
                HStack {
                    TextField("Enter message", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading)
                    
                    Button(action: {
                        if let data = messageText.data(using: .utf8) {
                            if let bridgefy = bridgefy {
                                let bridgefyManager = BridgefyManager(bridgefyInstance: bridgefy,
                                                                    delegate: MyBridgefyDelegate())
                                bridgefyManager.sendData(data,
                                                       transmissionMode: .broadcast(senderId: UUID()))
                                messageText = ""
                            }
                        }
                    }) {
                        Text("Send")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(messageText.isEmpty)
                    .padding(.trailing)
                }
                .padding(.bottom, 20)
                .background(Color.white)
                .shadow(radius: 5, y: -5)
            }
        }
    }
}

#Preview {
    ContentView()
}
