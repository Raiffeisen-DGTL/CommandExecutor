//
//  File.swift
//  
//
//  Created by USOV Vasily on 19.07.2024.
//

import Foundation

public actor CommandOutput {
    private(set) public var outputs: [String] = []
    
    public init(outputs: [String] = []) {
        self.outputs = outputs
    }
    
    public func add(output: String) {
        outputs.append(output)
    }
}
