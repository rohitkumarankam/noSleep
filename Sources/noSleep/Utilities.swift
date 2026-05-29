// Utilities.swift

import Foundation

@discardableResult
func run(_ executable: String, _ args: String..., suppressStderr: Bool = false, captureOutput: Bool = true) -> (output: String, status: Int32) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = args
    task.standardError = suppressStderr ? FileHandle.nullDevice : nil

    var pipe: Pipe?
    if captureOutput {
        let p = Pipe()
        task.standardOutput = p
        pipe = p
    } else {
        task.standardOutput = FileHandle.nullDevice
    }

    do {
        try task.run()
    } catch {
        fputs("[ERROR] Unable to run \(executable): \(error)\n", stderr)
        return ("", -1)
    }

    task.waitUntilExit()
    if let p = pipe {
        let data = p.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "", task.terminationStatus)
    }
    return ("", task.terminationStatus)
}

// osascript because UNUserNotificationCenter requires bundled app.
// Spawned detached via posix_spawn — no waitpid, no Foundation Process
// monitoring thread, no thread leak on repeated lid-close events.
func notify(_ message: String, subtitle: String? = nil, sound: String = "Glass") {
    func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
    var script = "display notification \"\(escape(message))\" with title \"noSleep\""
    if let sub = subtitle {
        script += " subtitle \"\(escape(sub))\""
    }
    script += " sound name \"\(escape(sound))\""

    // SIG_IGN on SIGCHLD tells the kernel to auto-reap children so
    // zombies don't accumulate across repeated notifications.
    signal(SIGCHLD, SIG_IGN)
    let args: [String] = ["/usr/bin/osascript", "-e", script]
    var argv = args.map { strdup($0) } + [nil]
    var pid: pid_t = 0
    posix_spawn(&pid, argv[0], nil, nil, &argv, nil)
    argv.forEach { free($0) }
}

func notifyPreventing() {
    notify("Sleep prevention active", subtitle: "AC Power + Lid Closed", sound: "Hero")
}

func notifyRestored(reason: String) {
    notify("Normal behaviour restored", subtitle: reason, sound: "Glass")
}
