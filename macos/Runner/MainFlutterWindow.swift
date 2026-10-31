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
      name: "maccleaner/recycle",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      if call.method == "recycle" {
        guard let paths = call.arguments as? [String] else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Paths should be a list of strings", details: nil))
          return
        }
        guard !paths.isEmpty, paths.allSatisfy({ self.isSafeRecyclePath($0) }) else {
          result(FlutterError(
            code: "UNSAFE_PATH",
            message: "A operação contém um caminho fora das áreas aprovadas ou um link simbólico.",
            details: nil
          ))
          return
        }
        let urls = paths.map { URL(fileURLWithPath: $0) }
        NSWorkspace.shared.recycle(urls) { (newURLs, error) in
          if let error = error {
            if self.isPermissionError(error as NSError) {
              result(FlutterError(
                code: "PERMISSION_DENIED",
                message: "O macOS não autorizou mover este item para a Lixeira.",
                details: nil
              ))
            } else {
              result(FlutterError(code: "RECYCLE_ERROR", message: error.localizedDescription, details: nil))
            }
          } else {
            result(true)
          }
        }
      } else if call.method == "openPrivacySettings" {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
          result(false)
          return
        }
        result(NSWorkspace.shared.open(url))
      } else if call.method == "requestContainerAccess" {
        guard let path = call.arguments as? String,
              self.isAppContainerPath(path),
              self.isSafeRecyclePath(path) else {
          result(FlutterError(code: "UNSAFE_PATH", message: "Contêiner inválido.", details: nil))
          return
        }
        do {
          _ = try FileManager.default.contentsOfDirectory(atPath: path)
          result(true)
        } catch {
          let permissionDenied = self.isPermissionError(error as NSError)
          result(FlutterError(
            code: permissionDenied ? "PERMISSION_DENIED" : "ACCESS_ERROR",
            message: permissionDenied
              ? "O macOS não autorizou o acesso ao contêiner."
              : error.localizedDescription,
            details: nil
          ))
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

  private func isSafeRecyclePath(_ rawPath: String) -> Bool {
    let standardizedPath = (rawPath as NSString).standardizingPath
    let path = standardizedPath.lowercased()
    let home = (NSHomeDirectory() as NSString).standardizingPath.lowercased()

    let protectedRoots = [
      "/system", "/applications", "/library", "/bin", "/sbin", "/usr",
      "/dev", "/etc", "/opt", "/volumes", "/private/etc",
      "/private/var/db", "/private/var/root", "/private/var/run",
      "/private/var/vm", "/private/var/protected"
    ]
    if path == "/" || path == home || protectedRoots.contains(where: {
      path == $0 || path.hasPrefix($0 + "/")
    }) {
      return false
    }

    if let attributes = try? FileManager.default.attributesOfItem(atPath: standardizedPath),
       attributes[.type] as? FileAttributeType == .typeSymbolicLink {
      return false
    }

    let allowedRoots = [
      "Library/Caches", "Library/Logs", "Library/Application Support",
      "Library/Preferences", "Library/LaunchAgents", "Library/Containers",
      "Library/Fonts", "Library/Developer/Xcode/DerivedData",
      "Library/Developer/CoreSimulator/Caches", ".Trash", ".npm/_cacache",
      ".gradle/caches", ".m2/repository", "Downloads", "Desktop", "Documents"
    ].map { (home as NSString).appendingPathComponent($0).lowercased() }
      + ["/private/tmp", "/private/var/tmp"]

    return allowedRoots.contains(where: {
      path != $0 && path.hasPrefix($0 + "/")
    })
  }

  private func isPermissionError(_ error: NSError) -> Bool {
    if error.domain == NSCocoaErrorDomain &&
        [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(error.code) {
      return true
    }
    if error.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(error.code) {
      return true
    }
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
      return isPermissionError(underlying)
    }
    return false
  }

  private func isAppContainerPath(_ rawPath: String) -> Bool {
    let path = (rawPath as NSString).standardizingPath.lowercased()
    let root = ((NSHomeDirectory() as NSString).appendingPathComponent("Library/Containers") as NSString)
      .standardizingPath.lowercased()
    return path.hasPrefix(root + "/")
  }
}
