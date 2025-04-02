//
//  Errors.swift
//  CommandExecutor
//
//  Created by USOV Vasily on 18.02.2025.
//

import Foundation

public enum ServiceError {
    public enum Scenario: LocalizedError {
        case cantCreateExecutableFile(path: String)
        
        public var errorDescription: String? {
            switch self {
            case .cantCreateExecutableFile(path: let path):
                return "Can't create executable file at path: \(path)"
            }
        }
    }
    
    public enum Executor: LocalizedError {
        case shellError(code: Int32?, description: String?)
        case processError(any Error)
        
        public var errorDescription: String? {
            switch self {
            case .shellError(let code, let description):
                "Error during execution, code: \(code ?? 0), description: \(description ?? "nil")"
            case .processError(let error):
                "Process error: \(error.localizedDescription)"
            }
        }
    }
}
