//
//  CommandExecutor.swift
//  RaifMagic
//
//  Created by USOV Vasily on 28.05.2024.
//

import Foundation
import SwiftUI

// Service for executing shell commands
public actor CommandExecutor: Sendable {
    
    public protocol Logger: Sendable {
        func log(commandExecutorServiceMessage: String)
    }
    
    private lazy var shell: Shell = {
        do {
            let task = Process()
            let pipe = Pipe()
            
            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = ["-cl", "dscl . -read \(NSHomeDirectory()) UserShell | sed 's/UserShell: //'"]
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.standardInput = nil
            
            try task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Shell.init(rawValue: output) ?? .zsh
        } catch {
            return .zsh
        }
    }()
    
    private let logger: Logger
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    /// Execute a command and return the output as one value.
    ///
    /// Used when you just need to wait for the execution results and not process AsyncThrowingStream
    /// - Throws:
    ///     - `CommandExecutor.ServiceError`
    public func execute(сommandWithSingleOutput textCommand: String, atPath path: String? = nil) async throws -> String {
        let result = CommandOutput()
        try await execute(textCommand: textCommand, atPath: path) { line in
            await result.add(output: line.asString)
        }
        return await result.outputs.joined(separator: " ")
    }
    
    /// Execute a console command.
    ///
    /// Returns a stream from which the command output can be read.
    /// - Parameters:
    /// - _: The command to execute
    /// - Returns: AsyncThrowingStream returning the results of the command execution
    public func execute(_ command: Command, handler: (@Sendable (ConsoleLine) async -> Void)? = nil) async throws {
        try await execute(textCommand: command.asString, atPath: command.executeAtPath) { line in
            await handler?(line)
        }
    }
    
    /// Execute a command. Cancellation of the task in which this method is launched is supported
    /// - Parameters:
    ///     - textCommand: Text representation of the command
    ///     - executedAt: Path by which this command should be called
    ///     - handler: Output handler. Called for each value returned during execution
    public func execute(textCommand: String,
                        atPath executedAt: String? = nil,
                        handler: (@Sendable (ConsoleLine) async -> Void)? = nil) async throws {
        let execution = CommandExecution()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let _execution: CommandExecution = run(textCommand: textCommand, atPath: executedAt)
            await execution.copy(fromExecution: _execution)
            try Task.checkCancellation()
            guard let stream = await execution.stream else { return }
            for try await item in stream {
                try Task.checkCancellation()
                await handler?(item)
            }
        } onCancel: {
            Task {
                self.logger.log(commandExecutorServiceMessage: "КОМАНДА: \(textCommand)\n\tПринудительное завершение выполнения команды")
                await execution.process?.terminate()
            }
        }
    }
    
    /// Start executing a console command.
    /// - Parameters:
    ///     - textCommand: Text representation of the command to execute
    ///     - atFolder: Path to the folder to navigate to before calling the command.
    /// - Returns: `CommandExecutionContainer` - a container with a process and a stream. The process allows you to terminate program execution if necessary. The stream is used to process the output of the console command.
    private func run(textCommand: String,
                     atPath path: String? = nil
    ) -> CommandExecution {
        // TODO: There might be a failure here because of ! but let's wait for someone to crash
        // Otherwise, we'll have to move all the execution methods to throws
        // Now this seems unnecessary, since the error is not reproducible (probably)
        let processContainer = try! processContainer(forCommand: textCommand, atFolder: path)
        let stream = AsyncThrowingStream<ConsoleLine, Error> { continuation in
            
            Task { [continuation] in
                
                continuation.onTermination = { _ in
                    processContainer.pipe.fileHandleForReading.readabilityHandler = nil
                    processContainer.errorPipe.fileHandleForReading.readabilityHandler = nil
                }
                
                async let errorHandling: Void = await withCheckedContinuation { errorContinuation in
                    processContainer.errorPipe.fileHandleForReading.readabilityHandler = { [errorContinuation] handle in
                        let itemOutput = handle.availableData
                        guard itemOutput.isEmpty == false else {
                            processContainer.errorPipe.fileHandleForReading.readabilityHandler = nil
                            errorContinuation.resume()
                            return
                        }
                        let outputString = (String(data: itemOutput, encoding: String.Encoding.utf8) ?? "").components(separatedBy: "\n").filter({ $0 != "" }).joined()
                        let line = self.convertRawOutputStringToConsoleLine(outputString, forceColor: .yellow)
                        Task {
                            self.logger.log(commandExecutorServiceMessage: "КОМАНДА: \(textCommand)\n\tОшибка: \(outputString)")
                        }
                        continuation.yield(line)
                    }
                }
                async let outputHandling: Void = await withCheckedContinuation { outputContinuation in
                    processContainer.pipe.fileHandleForReading.readabilityHandler = { handle in
                        let itemOutput = handle.availableData
                        
                        guard !itemOutput.isEmpty else {
                            processContainer.pipe.fileHandleForReading.readabilityHandler = nil
                            outputContinuation.resume()
                            return
                        }
                        
                        let outputString = (String(data: itemOutput, encoding: String.Encoding.utf8) ?? "").components(separatedBy: "\n").filter({ $0 != "" }).joined()
                        let line = self.convertRawOutputStringToConsoleLine(outputString)
                        Task {
                            self.logger.log(commandExecutorServiceMessage: "КОМАНДА: \(textCommand)\n\tПолучены данные: \(outputString)")
                        }
                        continuation.yield(line)
                    }
                }
                
                do {
                    Task {
                        self.logger.log(commandExecutorServiceMessage: "КОМАНДА: \(textCommand)\n\tЗапуск по пути:\(path ?? "не указана")")
                    }
                    try processContainer.process.run()
                } catch {
                    continuation.finish(throwing: ServiceError.Executor.processError(error))
                }
                
                await errorHandling
                await outputHandling
                
                processContainer.process.terminationHandler = { process in
                    Task {
                        self.logger.log(commandExecutorServiceMessage: "КОМАНДА: \(textCommand)\n\tВыполнение завершено с кодом: \(process.terminationStatus)")
                    }
                    if process.terminationStatus == 0 {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: ServiceError.Executor.shellError(code: process.terminationStatus, description: "Ошибка выполнения команды"))
                    }
                }
            }
        }
        return CommandExecution(process: processContainer.0, stream: stream)
    }
    
    // MARK: - Helpers
    
    // TODO: If there is a match at the beginning of [33m in the line, then you need to add the following output until a normal entry appears
    // Moreover, there should be the same number of matches on [33m [0m as on [33m separately
    // Here is an example of a crooked output
    // [31mError:
    // [0m [31mThe project cannot be fo
    // und at //Pods/Pods.xco
    // deproj [0m
    nonisolated public func convertRawOutputStringToConsoleLine(_ rawString: String, forceColor: ConsoleLineItem.Color? = nil) -> ConsoleLine {
        let pattern = /\[(\d+)m(.+?)\[0m/
        let matches = rawString.matches(of: pattern)
        if matches.count == 0 {
            let singleItem = ConsoleLineItem(content: rawString, color: forceColor ?? .default)
            return ConsoleLine(item: singleItem)
        } else {
            let items = matches.map { match in
                let color: ConsoleLineItem.Color = {
                    guard let numericColor = Int(match.output.1) else { return .default }
                    return switch numericColor {
                    case 30: .default
                    case 31: .red
                    case 32: .green
                    case 33: .yellow
                    case 34: .blue
                    case 35: .purple
                    case 36: .blue
                    case 37: .white
                    default: .default
                    }
                }()
                return ConsoleLineItem(content: String(match.output.2).trimmingCharacters(in: .whitespacesAndNewlines), color: forceColor ?? color)
            }
            return ConsoleLine(items: items)
        }
    }
    
    // Creates a new process to execute the command
    private func processContainer(forCommand textCommand: String, atFolder path: String?) throws -> (process: Process, pipe: Pipe, errorPipe: Pipe) {
        let homeDirURL = URL(fileURLWithPath: NSHomeDirectory())
        let runShell = shell.rawValue
        Task { [runShell] in
            self.logger.log(commandExecutorServiceMessage: "КОМАНДА: \(textCommand)\n\tВыбран шелл: \(runShell)")
        }
        
        let fileManager = FileManager.default
        var sourceRC = ""
        if runShell == "/bin/bash" {
            if fileManager.fileExists(atPath: "\(homeDirURL.path)/.bashrc") {
                sourceRC += "source \(homeDirURL.path)/.bashrc &&"
            }
        }
        if runShell == "/bin/zsh" {
            if fileManager.fileExists(atPath: "\(homeDirURL.path)/.zshrc") {
                sourceRC += "source \(homeDirURL.path)/.zshrc &&"
            }
        }
        
        let process = Process()
        let pipe = Pipe()
        
        let command = if let path {
            "(cd \(path) && \(textCommand))"
        } else {
            textCommand
        }
        
        let errorPipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.standardInput
        
        process.arguments = ["--login", "-cl", "export HOME=\(homeDirURL.path) && export LANG=en_US.UTF-8 &&  \(sourceRC)" + command]
        process.launchPath = runShell
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        return (process, pipe, errorPipe)
    }
    
    // MARK: - Subtypes
    
    public enum Shell: String {
        case zsh = "/bin/zsh"
        case bash = "/bin/bash"
    }
}
