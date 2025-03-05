import Foundation
import UIKit

class APIWorker: ObservableObject {
    @Published var hostname = "https://maciejgad.pl/faceLiveness"
    @Published var username = ""
    @Published var password = ""
    
    func fetchSessionID() async throws -> String {
        let link = "\(hostname)/create_liveness_session"
        let response: LivenessSession = try await fetch(link: link)
        return response.sessionID
    }
    
    func fetchLivenessResult(sessionID: String) async throws -> LivenessResult {
        let link = "\(hostname)/get_liveness_result/\(sessionID)"
        return try await fetch(link: link)
    }
    
    func fetch<T: Decodable>(link: String) async throws -> T {
        guard let url = URL(string: link) else {
            throw APIError.invalidURL
        }
        let request = buildRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse  else {
            throw APIError.invalidResponse
        }
        guard response.statusCode == 200 else {
            if response.statusCode == 401 {
                throw APIError.invalidCredentials
            } else {
                throw APIError.backendError(code: response.statusCode)
            }
        }
        let jsonDecoder = JSONDecoder()
        return try jsonDecoder.decode(T.self, from: data)
    }
    
    func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        let loginString = "\(username):\(password)"
        let loginData = Data(loginString.utf8)
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    func openDetails(for sessionID: String) {
        guard let url = URL(string: "\(hostname)/details/\(sessionID)") else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    enum APIError: Swift.Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case noSessionID
        case invalidCredentials
        case backendError(code: Int)
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response"
            case .noSessionID:
                return "No session ID"
            case .invalidCredentials:
                return "Invalid credentials"
            case .backendError(let code):
                return "Backend error: \(code)"
            case .unknown:
                return "Unknown error"
            }
        }
    }
}
