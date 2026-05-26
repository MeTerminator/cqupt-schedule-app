import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let icloudChannel = FlutterMethodChannel(name: "top.met6.cquptschedule/icloud", binaryMessenger: flutterViewController.engine.binaryMessenger)
    icloudChannel.setMethodCallHandler { (call, result) in
        if call.method == "isAvailable" {
            result(true)
        } else if call.method == "setString" {
            guard let args = call.arguments as? [String: Any],
                  let key = args["key"] as? String,
                  let value = args["value"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Key and Value must be strings", details: nil))
                return
            }
            NSUbiquitousKeyValueStore.default.set(value, forKey: key)
            NSUbiquitousKeyValueStore.default.synchronize()
            result(true)
        } else if call.method == "getString" {
            guard let key = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Key must be a string", details: nil))
                return
            }
            result(NSUbiquitousKeyValueStore.default.string(forKey: key))
        } else if call.method == "remove" {
            guard let key = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Key must be a string", details: nil))
                return
            }
            NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
            NSUbiquitousKeyValueStore.default.synchronize()
            result(true)
        } else if call.method == "getAllData" {
            let dict = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
            var stringDict: [String: String] = [:]
            for (key, val) in dict {
                if let strVal = val as? String {
                    stringDict[key] = strVal
                }
            }
            result(stringDict)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    super.awakeFromNib()
  }
}
