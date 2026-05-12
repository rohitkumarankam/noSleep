// Utilities.swift

import Foundation

@discardableResult
func run(_ executable: String, _ args: String..., suppressStderr: Bool = false, timeout: TimeInterval = 5) -> (output: String, status: Int32) {
    let task = Process()
    let pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = args
    task.standardOutput = pipe
    task.standardError = suppressStderr ? FileHandle.nullDevice : pipe

    let semaphore = DispatchSemaphore(value: 0)
    task.terminationHandler = { _ in semaphore.signal() }

    do {
        try task.run()
    } catch {
        fputs("[ERROR] Unable to run \(executable): \(error)\n", stderr)
        return ("", -1)
    }

    if semaphore.wait(timeout: .now() + timeout) == .timedOut {
        task.terminate()
        semaphore.wait()
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (String(data: data, encoding: .utf8) ?? "", task.terminationStatus)
}

func getUID() -> String {
    return "\(getuid())"
}

// osascript because UNUserNotificationCenter requires bundled app
func notify(_ message: String, subtitle: String? = nil, sound: String = "Glass") {
    // Escape backslashes first, then quotes — these are AppleScript string-literal
    // escapes, not shell escapes. run() handles argv safely, but the message is
    // still interpolated into an AppleScript source string.
    func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
    var script = "display notification \"\(escape(message))\" with title \"noSleep\""
    if let sub = subtitle {
        script += " subtitle \"\(escape(sub))\""
    }
    script += " sound name \"\(escape(sound))\""
    run("/usr/bin/osascript", "-e", script)
}

func notifyPreventing() {
    notify("Sleep prevention active", subtitle: "AC Power + Lid Closed", sound: "Hero")
}

func notifyRestored(reason: String) {
    notify("Normal behaviour restored", subtitle: reason, sound: "Glass")
}
