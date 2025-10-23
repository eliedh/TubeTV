//
//  PingResponse.swift
//  TubeTV
//
//  Created by Copilot on 22.10.25.
//

import Foundation

struct PingResponse: Decodable {
    let response: String
    let user: Int
    let version: String
    let taUpdate: TAUpdate?
    
    enum CodingKeys: String, CodingKey {
        case response
        case user
        case version
        case taUpdate = "ta_update"
    }
    
    struct TAUpdate: Decodable {
        let status: Bool
        let version: String
        let isBreaking: Bool
        
        enum CodingKeys: String, CodingKey {
            case status
            case version
            case isBreaking = "is_breaking"
        }
    }
    
    var isValid: Bool {
        return response == "pong"
    }
}
