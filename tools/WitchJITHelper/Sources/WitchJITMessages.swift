import Foundation

/// Messages exchanged between Witch and its JIT helper extension.
///
/// The host encodes a `WitchJITRequest` as JSON into the first
/// `NSExtensionItem.userInfo` value; the helper returns a
/// `WitchJITResponse` the same way. Pairing data never appears in logs.
struct WitchJITRequest: Codable, Sendable {
    static let itemKey = "witch-jit-request"

    enum Operation: String, Codable, Sendable {
        case prepare
        case enable
        case resetDDI
    }

    let operation: Operation
    let targetPID: Int32?
    let pairingData: Data?
    let scriptBase64: String?
    let forceScript: Bool?
    /// The RemotePairing port this boot is advertising. nil uses StikJIT's default.
    let rsdPort: UInt16?

    static func prepare(pairingData: Data, rsdPort: UInt16? = nil) -> WitchJITRequest {
        WitchJITRequest(operation: .prepare, targetPID: nil, pairingData: pairingData,
                        scriptBase64: nil, forceScript: nil, rsdPort: rsdPort)
    }

    static func enable(targetPID: Int32, pairingData: Data, scriptBase64: String,
                       forceScript: Bool, rsdPort: UInt16? = nil) -> WitchJITRequest {
        WitchJITRequest(operation: .enable, targetPID: targetPID, pairingData: pairingData,
                        scriptBase64: scriptBase64, forceScript: forceScript, rsdPort: rsdPort)
    }

    static var resetDDI: WitchJITRequest {
        WitchJITRequest(operation: .resetDDI, targetPID: nil, pairingData: nil,
                        scriptBase64: nil, forceScript: nil, rsdPort: nil)
    }
}

struct WitchJITResponse: Codable, Sendable {
    static let itemKey = "witch-jit-response"

    let success: Bool
    let message: String
    let txmPresent: Bool?
}
