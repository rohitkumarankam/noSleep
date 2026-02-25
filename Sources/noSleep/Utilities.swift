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

    try? task.run()

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
    var script = "display notification \"\(message)\" with title \"noSleep\""
    if let sub = subtitle {
        script += " subtitle \"\(sub)\""
    }
    script += " sound name \"\(sound)\""
    run("/usr/bin/osascript", "-e", script)
}

func notifyPreventing() {
    notify("Sleep prevention active", subtitle: "AC Power + Lid Closed", sound: "Hero")
}

func notifyRestored(reason: String) {
    notify("Normal behaviour restored", subtitle: reason, sound: "Glass")
}
