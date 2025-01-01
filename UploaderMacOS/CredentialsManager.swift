//
//  CredentialsManager.swift
//  UploaderMacOS
//
//  Created by Michał on 01/01/2025.
//

import Foundation

class CredentialsManager {
    static let shared = CredentialsManager()
    
    var login: String = ""
    var password: String = ""
    var apiKey: String = ""
    
    private init() {
        loadCredentials()
    }
    
    private func loadCredentials() {
        if let credentials = loadCredentials(from: "credentials.properties") {
            login = credentials["RAPIDGATOR_LOGIN"] ?? ""
            password = credentials["RAPIDGATOR_PASSWORD"] ?? ""
            apiKey = credentials["RAPIDGATOR_API"] ?? ""
        } else {
            print("Failed to load credentials.")
        }
    }
    
    private func loadCredentials(from fileName: String) -> [String: String]? {
        guard let filePath = Bundle.main.path(forResource: fileName, ofType: nil as String?) else {
            print("Could not load the file path.")
            return nil
        }
        
        guard let content = try? String(contentsOfFile: filePath) else {
            print("Could not read the file at path: \(filePath)")
            return nil
        }
        
        var credentials: [String: String] = [:]
        
        let lines = content.split(separator: "\n")
        for line in lines {
            let keyValue = line.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(keyValue[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                credentials[key] = value
            }
        }
        
        return credentials
    }
}
