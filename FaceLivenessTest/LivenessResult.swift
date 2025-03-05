//
//  Untitled.swift
//  FaceLivenessTest
//
//  Created by bazyl on 04/03/2025.
//

struct LivenessResult: Codable {
    let status: Status
    let confidence: Double
    let sessionID: String
    
    enum Status: String, Codable {
        case created = "CREATED"
        case inProgress = "IN_PROGRESS"
        case success = "SUCCEEDED"
        case failure = "FAILED"
        case expired = "EXPIRED"
    }
    
    enum CodingKeys: String, CodingKey {
        case status
        case confidence
        case sessionID = "session_id"
    }
}

