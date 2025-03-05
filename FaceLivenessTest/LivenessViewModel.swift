import SwiftUI
import Foundation

class LivenessViewModel: ObservableObject {
    @Published var loading = false
    @Published var sessionID: String?
    @Published var showLiveness = false
    @Published var livenessResult: LivenessResult?
    @Published var localCheckOutput: String?
    @Published var debug = ""
    
    @Published var apiWorker = APIWorker()
    
    func onFetchSession() {
        livenessResult = nil
        loading = true
        sessionID = nil
        Task {
            do {
                let sessionID = try await apiWorker.fetchSessionID()
                await startLivenessCheck(sessionId: sessionID)
            } catch {
                await show(error: error)
            }
        }
    }
    
    @MainActor
    func show(error: Error) {
        debug = "Error: \(error.localizedDescription)"
        loading = false
    }
    
    @MainActor
    func startLivenessCheck(sessionId: String) {
        self.sessionID = sessionId
        showLiveness = true
        loading = false
        debug = ""
    }
    
    func onFetchResults() {
        loading = true
        Task {
            do {
                if let sessionID = sessionID {
                    let result = try await apiWorker.fetchLivenessResult(sessionID: sessionID)
                    await show(livenessResult: result)
                }
            } catch {
                await show(error: error)
            }
        }
    }
    
    @MainActor
    func show(livenessResult: LivenessResult) {
        self.livenessResult = livenessResult
        loading = false
        debug = ""
    }
}
