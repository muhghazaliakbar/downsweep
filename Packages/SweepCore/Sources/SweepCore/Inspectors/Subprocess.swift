import Foundation

enum SubprocessError: Error, Equatable {
    case failed(status: Int32)
    case timedOut
}

/// Runs a system tool with no stdin, returning stdout. Kills it after `timeout` seconds.
enum Subprocess {
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 10) async throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        // Drain stdout while the tool runs so large listings cannot fill the pipe and stall it.
        let output = Pipe()
        let buffer = OutputBuffer()
        output.fileHandleForReading.readabilityHandler = { handle in buffer.append(handle.availableData) }
        process.standardOutput = output

        let timer = Task {
            try await Task.sleep(for: .seconds(timeout))
            if process.isRunning { process.terminate() }
        }
        defer { timer.cancel() }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                output.fileHandleForReading.readabilityHandler = nil
                buffer.append(output.fileHandleForReading.readDataToEndOfFile())
                if process.terminationReason == .uncaughtSignal {
                    continuation.resume(throwing: SubprocessError.timedOut)
                } else if process.terminationStatus != 0 {
                    continuation.resume(throwing: SubprocessError.failed(status: process.terminationStatus))
                } else {
                    continuation.resume(returning: buffer.data)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ chunk: Data) {
        lock.withLock { storage.append(chunk) }
    }

    var data: Data { lock.withLock { storage } }
}
