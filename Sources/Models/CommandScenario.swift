//
//  CommandScenario.swift
//  RaifMagic
//
//  Created by USOV Vasily on 30.05.2024.
//

import Foundation

/// Container for commands
///
/// Scenario consists of a set of commands that can be executed,
/// Later it is used either for unloading into a sh file for running in the terminal
/// or for calling via CommandExecutor (a service that executes console commands)
public struct CommandScenario: Sendable {
    public var title: String?
    public var steps: [Step] = []
    
    public init(title: String? = nil) {
        self.title = title
    }

    public mutating func add(command: Command, isRequiredSuccess: Bool = true) {
        steps.append(Step(command: command, isRequiredSuccess: isRequiredSuccess))
    }
    public mutating func addPrefix(command: Command, isRequiredSuccess: Bool = true) {
        self.steps.insert(Step(command: command, isRequiredSuccess: isRequiredSuccess), at: 0)
    }
    
    // MARK: - Helpers
    
    /// Saves the script as an executable script at the specified path
    public func saveAsExecutableFile(path: String, name: String? = nil) throws(ServiceError.Scenario) -> String {
        let name = name ?? UUID().uuidString
        let scriptPath = path + "/" + name + ".sh"
        var commands = self.steps.compactMap { step -> [String] in
            if let path = step.command.executeAtPath {
                ["echo \"\" && \\",
                 "echo \"cd \(path)\" && \\",
                 "echo \"\(step.command.asString)\" && \\",
                 "cd \(path) && \(step.command.asString)" + (step.isRequiredSuccess ? "" : " && \\"),
                ]
            } else {
                ["echo \"\" && \\",
                 "echo \"\(step.command.asString)\" && \\",
                 step.command.asString + (step.isRequiredSuccess ? "" : " && \\")]
            }
        }.flatMap({$0})
        commands.append("echo \"-------\" && \\")
        commands.append("echo \"Generation finished successfully\" && \\")
        commands.append("echo \"-------\"")
        
        guard FileManager.default.createFile(atPath: scriptPath, contents: commands.joined(separator: "\n").data(using: .utf8), attributes: [FileAttributeKey.posixPermissions: NSNumber(value: 0o755)]) else {
            throw ServiceError.Scenario.cantCreateExecutableFile(path: name)
        }
        
        return scriptPath
    }
    
    /// One step of scenario
    public struct Step: Sendable, Identifiable {
        public let id = UUID()
        public let command: Command
        public let isRequiredSuccess: Bool
        
        init(command: Command, isRequiredSuccess: Bool = true) {
            self.command = command
            self.isRequiredSuccess = isRequiredSuccess
        }
    }
}
