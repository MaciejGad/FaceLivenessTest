import Foundation

struct LivenessSession: Codable {
    let sessionID: String
    
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}
