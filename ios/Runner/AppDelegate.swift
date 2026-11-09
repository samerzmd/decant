import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  // ---- Store-delivered sound packs (On-Demand Resources) ------------------ //
  // The extra ambience/music loops are tagged "ambient" / "music" in the
  // Xcode project and listed in ON_DEMAND_RESOURCES_PREFETCH_ORDER, so the
  // App Store downloads them right after install. Dart talks to this bridge
  // through lib/audio/sound_packs.dart.
  private var packRequests: [String: NSBundleResourceRequest] = [:]
  private var packAccessing: Set<String> = []
  private var packWaiters: [String: [(Bool) -> Void]] = [:]
  private var packProgress: [String: NSKeyValueObservation] = [:]
  private var packEvents: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// UIScene lifecycle: the Flutter engine is created by the scene, so plugins
  /// and our own channels are registered here rather than at launch.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DecantSoundPacks") {
      let channel = FlutterMethodChannel(
        name: "decant/sound_packs", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handlePacks(call, result)
      }
      FlutterEventChannel(
        name: "decant/sound_packs/events", binaryMessenger: registrar.messenger()
      ).setStreamHandler(self)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    packEvents = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    packEvents = nil
    return nil
  }

  private func handlePacks(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let pack = args["pack"] as? String else {
      result(FlutterError(code: "ARG", message: "pack is required", details: nil))
      return
    }
    switch call.method {
    case "resolve":
      let file = (args["file"] as? String) ?? ""
      withPack(pack, download: false) { ok in
        guard ok else { return result(nil) }
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        result(Bundle.main.path(forResource: name, ofType: ext))
      }
    case "fetch":
      withPack(pack, download: true) { ok in result(ok) }
    case "state":
      withPack(pack, download: false) { ok in
        result(["pack": pack, "status": ok ? "completed" : "notInstalled"])
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Gain access to a pack's resources, optionally downloading them. Calls
  /// are coalesced so a request is only ever begun once at a time.
  private func withPack(_ pack: String, download: Bool, _ done: @escaping (Bool) -> Void) {
    if packAccessing.contains(pack) { return done(true) }
    if packWaiters[pack] != nil {
      packWaiters[pack]!.append(done)
      return
    }
    packWaiters[pack] = [done]
    let req = packRequests[pack] ?? NSBundleResourceRequest(tags: [pack])
    packRequests[pack] = req
    req.conditionallyBeginAccessingResources { available in
      DispatchQueue.main.async {
        if available { return self.finish(pack, true) }
        guard download else { return self.finish(pack, false) }
        self.emit(pack, "downloading", 0)
        self.packProgress[pack] = req.progress.observe(\.fractionCompleted) { p, _ in
          self.emit(pack, "downloading", p.fractionCompleted)
        }
        req.beginAccessingResources { error in
          DispatchQueue.main.async {
            self.packProgress[pack] = nil
            if error != nil { self.packRequests[pack] = nil }  // can't be reused
            self.emit(pack, error == nil ? "completed" : "failed", error == nil ? 1 : 0)
            self.finish(pack, error == nil)
          }
        }
      }
    }
  }

  private func finish(_ pack: String, _ ok: Bool) {
    if ok { packAccessing.insert(pack) }
    let waiters = packWaiters.removeValue(forKey: pack) ?? []
    waiters.forEach { $0(ok) }
  }

  private func emit(_ pack: String, _ status: String, _ fraction: Double) {
    DispatchQueue.main.async {
      self.packEvents?([
        "pack": pack, "status": status,
        "downloaded": Int(fraction * 1000), "total": 1000,
      ])
    }
  }
}
