import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerLaunchAtStartupChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func registerLaunchAtStartupChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "launch_at_startup", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "launchAtStartupIsEnabled":
        result(LaunchAgent.isEnabled)
      case "launchAtStartupSetEnabled":
        let enabled = (call.arguments as? [String: Any])?["setEnabledValue"] as? Bool ?? false
        do {
          try LaunchAgent.setEnabled(enabled)
          result(nil)
        } catch {
          result(FlutterError(code: "LAUNCH_AGENT", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

enum LaunchAgent {
  static var label: String { Bundle.main.bundleIdentifier ?? "com.yora.app" }

  static var plistURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/LaunchAgents/\(label).plist")
  }

  static var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

  static func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try FileManager.default.createDirectory(
        at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      let plist: [String: Any] = [
        "Label": label,
        "ProgramArguments": [Bundle.main.executablePath ?? ""],
        "RunAtLoad": true,
      ]
      let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
      try data.write(to: plistURL)
    } else if isEnabled {
      try FileManager.default.removeItem(at: plistURL)
    }
  }
}
