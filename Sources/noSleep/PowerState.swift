// PowerState.swift

import Foundation
import IOKit.ps

struct PowerState {
    let isOnAC: Bool
    let isLidClosed: Bool
    let batteryPercent: Int?
}

func getCurrentPowerState() -> PowerState {
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

    let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
    let isOnAC = type == kIOPSACPowerValue as String

    var batteryPercent: Int?
    if let source = sources.first,
       let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
        batteryPercent = desc[kIOPSCurrentCapacityKey] as? Int
    }

    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    var lidClosed = false
    if service != 0 {
        defer { IOObjectRelease(service) }
        if let prop = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0) {
            lidClosed = prop.takeRetainedValue() as? Bool ?? false
        }
    }

    return PowerState(isOnAC: isOnAC, isLidClosed: lidClosed, batteryPercent: batteryPercent)
}
