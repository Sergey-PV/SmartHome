import Foundation

#if canImport(UIKit)
import UIKit
#endif

protocol DeviceContextProviding: Sendable {
    func currentDeviceContext() -> DeviceContext
}

final class DefaultDeviceContextProvider: DeviceContextProviding, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let deviceIDKey = "com.sergey.parfenchyk.smarthome.auth.device-id"

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func currentDeviceContext() -> DeviceContext {
        let systemVersion: String
        let deviceName: String

        #if canImport(UIKit)
        systemVersion = UIDevice.current.systemVersion
        deviceName = UIDevice.current.name
        #else
        systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        deviceName = ProcessInfo.processInfo.hostName
        #endif

        return DeviceContext(
            deviceId: deviceID(),
            platform: "iOS",
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            osVersion: systemVersion,
            deviceModel: hardwareIdentifier(),
            deviceName: deviceName
        )
    }

    private func deviceID() -> String {
        if let existing = userDefaults.string(forKey: deviceIDKey) {
            return existing
        }

        let newValue = UUID().uuidString.lowercased()
        userDefaults.set(newValue, forKey: deviceIDKey)
        return newValue
    }

    private func hardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { identifier, child in
            guard let value = child.value as? Int8, value != 0 else {
                return
            }
            identifier.append(Character(UnicodeScalar(UInt8(value))))
        }
    }
}
