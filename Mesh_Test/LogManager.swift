import SwiftUI

class LogManager: ObservableObject {
    @Published var logMessages: [String] = []
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages.append(message)
        }
    }
}