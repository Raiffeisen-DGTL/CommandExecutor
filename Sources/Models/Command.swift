//
//  File.swift
//  
//
//  Created by USOV Vasily on 25.04.2024.
//

import Foundation
import SwiftUI

/// Represents a command that can be sent to the terminal
public struct Command: Identifiable, Hashable, Sendable {
    
    public static func == (lhs: Command, rhs: Command) -> Bool {
        lhs.id == rhs.id && lhs.items == rhs.items
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(items)
    }
    
    public var id: Int {
        items.hashValue
    }
    public var items: [String]
    public var executeAtPath: String?
    
    public init(_ textCommand: String, executeAtPath: String? = nil) {
        self.items = [textCommand]
        self.executeAtPath = executeAtPath
    }
    
    public mutating func addPostfix(_ postfix: String) {
        items.append(postfix)
    }
    
    public var asString: String {
        items.joined(separator: " ")
    }
}

