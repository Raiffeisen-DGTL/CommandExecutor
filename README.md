# CommandExecutor

A library for executing shell commands in Swift.

## Key Features

- Execute shell commands via a convenient API.
- Supports bash/zsh.
- Run individual commands or entire scripts.
- Option to save scripts to a `.sh` file for execution in the system terminal.
- Supports colored output for command results.
- Integrated with Swift Concurrency, including support for cancelling running commands when the associated Task is cancelled.

## Installation

The library is distributed as an SPM package. To install it, use the `Package.swift` file or the **Package Dependencies** section in your Xcode project settings.

## Usage

To work with CommandExecutor, you need to import it in the file where it will be used.

```swift
import CommandExecutor
```

All interaction goes through the `CommandExecutor` type. You also need to provide a logger conforming to the `CommandExecutor.Logger` protocol.

```swift
// Logger
struct Logger: CommandExecutor.Logger, Sendable {
	func log(commandExecutorServiceMessage m: String) {
		print(m)
	}
}

let executor = CommandExecutor(logger: Logger())
```

To execute shell commands, use the `execute` methods.

### Running a command and awaiting the final result

If you need to wait for the command to complete before handling the result, use the following method:

```swift
let _ = executor.execute(сommandWithSingleOutput: "ls", atPath: "/")
```

> The `atPath` parameter defines the path where the command will be executed and is optional.

### Running a command with real-time output handling

If you need to handle each output line while the console command is running, provide a callback:

```swift
// Option using a plain text command
let _ = executor.execute(textCommand: "ls", atPath: "/") { consoleLine in 
	print(consoleLine.asString)
}

// Option using a `Command` type
var command = Command("ls", executeAtPath: "/")
command.addPostfix("-a")
let _ = executor.execute(command) { consoleLine in 
	print(consoleLine.asString)
}
```