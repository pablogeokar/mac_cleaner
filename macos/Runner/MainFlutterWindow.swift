import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Setup MethodChannel for recycling files/directories to trash
    let channel = FlutterMethodChannel(
      name: "macsweep/recycle",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      if call.method == "recycle" {
        guard let paths = call.arguments as? [String] else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Paths should be a list of strings", details: nil))
          return
        }
        let urls = paths.map { URL(fileURLWithPath: $0) }
        NSWorkspace.shared.recycle(urls) { (newURLs, error) in
          if let error = error {
            result(FlutterError(code: "RECYCLE_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Configure window appearance (macOS premium look)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    super.awakeFromNib()
  }
}
