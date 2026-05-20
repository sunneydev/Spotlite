import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar / agent app, no Dock icon

let delegate = AppDelegate()
app.delegate = delegate
app.run()
