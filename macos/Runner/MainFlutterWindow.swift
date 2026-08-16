import Cocoa
import FlutterMacOS
import DiskArbitration

class MainFlutterWindow: NSWindow {
  private var diskChannel: FlutterMethodChannel?
  private var daSession: DASession?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    setupDiskEventListener(binaryMessenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func setupDiskEventListener(binaryMessenger: FlutterBinaryMessenger) {
    diskChannel = FlutterMethodChannel(
      name: "com.macntfs.pro/disk_events",
      binaryMessenger: binaryMessenger
    )

    // 1. 监听 NSWorkspace 卷挂载/卸载/重命名通知
    let workspaceCenter = NSWorkspace.shared.notificationCenter
    workspaceCenter.addObserver(
      forName: NSWorkspace.didMountNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.notifyDiskChanged(event: "didMount")
    }

    workspaceCenter.addObserver(
      forName: NSWorkspace.didUnmountNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.notifyDiskChanged(event: "didUnmount")
    }

    workspaceCenter.addObserver(
      forName: NSWorkspace.didRenameVolumeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.notifyDiskChanged(event: "didRenameVolume")
    }

    // 2. 监听 DiskArbitration 底层硬件事件 (U盘插入、物理推出、拔出、属性变动)
    if let session = DASessionCreate(kCFAllocatorDefault) {
      self.daSession = session
      DASessionSetDispatchQueue(session, DispatchQueue.main)

      let diskAppearedCallback: DADiskAppearedCallback = { disk, context in
        guard let context = context else { return }
        let window = Unmanaged<MainFlutterWindow>.fromOpaque(context).takeUnretainedValue()
        window.notifyDiskChanged(event: "diskAppeared")
      }

      let diskDisappearedCallback: DADiskDisappearedCallback = { disk, context in
        guard let context = context else { return }
        let window = Unmanaged<MainFlutterWindow>.fromOpaque(context).takeUnretainedValue()
        window.notifyDiskChanged(event: "diskDisappeared")
      }

      let diskDescriptionChangedCallback: DADiskDescriptionChangedCallback = { disk, keys, context in
        guard let context = context else { return }
        let window = Unmanaged<MainFlutterWindow>.fromOpaque(context).takeUnretainedValue()
        window.notifyDiskChanged(event: "diskDescriptionChanged")
      }

      let contextPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
      DARegisterDiskAppearedCallback(session, nil, diskAppearedCallback, contextPtr)
      DARegisterDiskDisappearedCallback(session, nil, diskDisappearedCallback, contextPtr)
      DARegisterDiskDescriptionChangedCallback(session, nil, nil, diskDescriptionChangedCallback, contextPtr)
    }
  }

  private func notifyDiskChanged(event: String) {
    DispatchQueue.main.async { [weak self] in
      self?.diskChannel?.invokeMethod("onDiskChanged", arguments: ["event": event])
    }
  }

  deinit {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    if let session = daSession {
      DASessionSetDispatchQueue(session, nil)
    }
  }
}
