import SwiftUI

struct PeerListView: View {
    let connectedUsers: Set<UUID>
    @Binding var selectedPeer: UUID?
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List(Array(connectedUsers), id: \.self) { peer in
                Button(action: {
                    selectedPeer = peer
                    isPresented = false
                }) {
                    HStack {
                        Text(peer.uuidString.prefix(8))
                        Spacer()
                        if peer == selectedPeer {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Peer")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
            .overlay(Group {
                if connectedUsers.isEmpty {
                    Text("No peers found\nMake sure other devices are running the app")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }
            })
        }
    }
}