import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Open as a tall, phone-like window, centered; the game lays out for
    // any size, so it can still be resized or made full screen.
    self.title = "Decant"
    self.contentMinSize = NSSize(width: 360, height: 560)
    self.setContentSize(NSSize(width: 480, height: 860))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
