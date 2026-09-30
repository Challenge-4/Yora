import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let trafficLightsLeft: CGFloat = 20
  private let topBarHeight: CGFloat = 80

  override var styleMask: NSWindow.StyleMask {
    didSet { scheduleTrafficLightsLayout() }
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerLaunchAtStartupChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()

    let notifications: [NSNotification.Name] = [
      NSWindow.didResizeNotification,
      NSWindow.didEndLiveResizeNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didBecomeMainNotification,
    ]
    for name in notifications {
      NotificationCenter.default.addObserver(
        self, selector: #selector(windowLayoutChanged), name: name, object: self)
    }
    scheduleTrafficLightsLayout()
  }

  @objc private func windowLayoutChanged() {
    positionTrafficLights()
  }

  private func scheduleTrafficLightsLayout() {
    DispatchQueue.main.async { [weak self] in self?.positionTrafficLights() }
  }

  private func positionTrafficLights() {
    guard !styleMask.contains(.fullScreen),
      let close = standardWindowButton(.closeButton),
      let miniaturize = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton),
      let container = close.superview?.superview
    else { return }

    let spacing = miniaturize.frame.minX - close.frame.minX
    container.frame = NSRect(
      x: 0,
      y: frame.height - topBarHeight,
      width: frame.width,
      height: topBarHeight)

    let y = (topBarHeight - close.frame.height) / 2
    for (index, button) in [close, miniaturize, zoom].enumerated() {
      button.setFrameOrigin(NSPoint(x: trafficLightsLeft + CGFloat(index) * spacing, y: y))
    }
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
