//
//  File.swift
//  
//
//  Created by USOV Vasily on 19.07.2024.
//

import Foundation

actor CommandExecution {
    public private(set) var process: Process?
    public private(set) var stream: AsyncThrowingStream<ConsoleLine, Error>?
    
    public init() {
        self.process = nil
        self.stream = nil
    }
    
    init(process: Process?, stream: AsyncThrowingStream<ConsoleLine, Error>?) {
        self.process = process
        self.stream = stream
    }
    
    public func copy(fromExecution execution: CommandExecution) async {
        (self.process, self.stream) = await (execution.process, execution.stream)
    }
    
    public func set(process: Process?, stream: AsyncThrowingStream<ConsoleLine, Error>?) {
        self.process = process
        self.stream = stream
    }
}

