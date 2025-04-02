//
//  ConsoleLine.swift
//  RaifMagic
//
//  Created by USOV Vasily on 04.06.2024.
//

import Foundation

public struct ConsoleLine: Sendable {
    public let items: [ConsoleLineItem]
    
    public init(item: ConsoleLineItem) {
        items = [item]
    }
    
    public init(items: [ConsoleLineItem]) {
        self.items = items
    }
    
    public var asString: String {
        items.asString
    }
}

public struct ConsoleLineItem: Sendable {
    public var content: String
    public var color: Color
    
    public init(content: String, color: Color = .default) {
        self.content = content
        self.color = color
    }
    
    public enum Color: Sendable {
        case `default`
        case green
        case yellow
        case red
        case blue
        case purple
        case white
    }
}

extension Array<ConsoleLineItem> {
    var asString: String {
        self.map(\.content).joined(separator:" ")
    }
}
