import Foundation
import StikJIT

/// The debugger half of Witch's Built-in StikJIT.
///
/// A process cannot synchronously debug itself, so Witch starts this extension,
/// sends it its PID, the pairing file and UniversalJIT26.js, and StikJIT attaches
/// over LocalDevVPN and services the script's trap requests until Witch detaches.
private enum WitchJITWork {
    /// One request at a time: enabling JIT holds this queue while the debugger is attached.
    static let queue = DispatchQueue(label: "com.witch.zad626.jit-helper")

    static func handle(_ request: WitchJITRequest) -> WitchJITResponse {
        let manager = FileManager.default
        let library = manager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let root = library.appendingPathComponent("StikJIT", isDirectory: true)
        let paths = DDIPaths.default(in: root)
        var configuration = StikJIT.Configuration.default
        if let rsdPort = request.rsdPort {
            configuration.rsdPort = rsdPort
        }

        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            try manager.createDirectory(at: root.appendingPathComponent("DDI", isDirectory: true),
                                        withIntermediateDirectories: true)
            if request.operation == .resetDDI {
                try StikJIT.resetCachedDDI(at: paths)
                return WitchJITResponse(success: true,
                                        message: "Developer Disk Image cache reset.",
                                        txmPresent: StikJIT.isTXMPresent)
            }

            guard let pairingData = request.pairingData, !pairingData.isEmpty else {
                throw NSError(domain: "WitchJITHelper", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "The pairing file was not provided."])
            }
            let pairingURL = root.appendingPathComponent("pairingFile-\(UUID().uuidString).plist")
            try pairingData.write(to: pairingURL, options: .atomic)
            defer { try? manager.removeItem(at: pairingURL) }

            switch request.operation {
            case .prepare:
                let readiness = StikJIT.prepareDevice(
                    pairingFile: pairingURL, paths: paths, configuration: configuration,
                    progress: { NSLog("[WitchJIT] prepare: %@", String(describing: $0)) })
                switch readiness {
                case .ready(let security):
                    return WitchJITResponse(
                        success: true,
                        message: "LocalDevVPN is reachable and the Developer Disk Image is ready.",
                        txmPresent: security.isTXMPresent)
                case .unreachable(let reason), .preparationFailed(let reason):
                    return WitchJITResponse(success: false, message: reason,
                                            txmPresent: StikJIT.isTXMPresent)
                @unknown default:
                    return WitchJITResponse(success: false,
                                            message: "StikJIT returned an unknown preparation state.",
                                            txmPresent: StikJIT.isTXMPresent)
                }
            case .enable:
                guard let targetPID = request.targetPID,
                      let scriptBase64 = request.scriptBase64, !scriptBase64.isEmpty else {
                    throw NSError(domain: "WitchJITHelper", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey:
                                    "The target process or Witch's JIT script was not provided."])
                }
                try StikJIT.enableJIT(
                    targetPID: targetPID,
                    pairingFile: pairingURL,
                    ddiPaths: paths,
                    configuration: configuration,
                    script: .customBase64(scriptBase64),
                    forceScript: request.forceScript ?? true,
                    preparationProgress: { NSLog("[WitchJIT] prepare: %@", String(describing: $0)) },
                    progress: { NSLog("[WitchJIT] %@", $0) })
                return WitchJITResponse(success: true,
                                        message: "Witch detached cleanly from its built-in JIT helper.",
                                        txmPresent: StikJIT.isTXMPresent)
            case .resetDDI:
                preconditionFailure("Handled above")
            }
        } catch {
            return WitchJITResponse(success: false, message: error.localizedDescription,
                                    txmPresent: StikJIT.isTXMPresent)
        }
    }
}

/// NSExtensionPrincipalClass (Info.plist). The request arrives as JSON in the
/// first input item; the response goes back as JSON in the item the request
/// completes with. Enable completes only once Witch's script has detached, so
/// the request, and this process, last as long as the debugger does.
@objc(WitchJITHelperHandler)
final class WitchJITHelperHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let info = (context.inputItems.first as? NSExtensionItem)?.userInfo
        let data = info?[WitchJITRequest.itemKey] as? Data
        WitchJITWork.queue.async {
            let response: WitchJITResponse
            if let data, let request = try? JSONDecoder().decode(WitchJITRequest.self, from: data) {
                response = WitchJITWork.handle(request)
            } else {
                response = WitchJITResponse(success: false,
                                            message: "Witch's JIT helper received no request.",
                                            txmPresent: nil)
            }
            let item = NSExtensionItem()
            item.userInfo = [WitchJITResponse.itemKey: (try? JSONEncoder().encode(response)) ?? Data()]
            context.completeRequest(returningItems: [item], completionHandler: nil)
        }
    }
}
