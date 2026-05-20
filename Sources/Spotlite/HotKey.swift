import AppKit
import Carbon.HIToolbox

/// Carbon-based global hotkey. Works without accessibility permission.
final class HotKey {
    struct Modifiers: OptionSet {
        let rawValue: UInt32
        static let command = Modifiers(rawValue: UInt32(cmdKey))
        static let option  = Modifiers(rawValue: UInt32(optionKey))
        static let control = Modifiers(rawValue: UInt32(controlKey))
        static let shift   = Modifiers(rawValue: UInt32(shiftKey))
    }

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var callback: (() -> Void)?

    func register(keyCode: UInt32, modifiers: Modifiers, callback: @escaping () -> Void) {
        self.callback = callback

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.callback?() }
            _ = event
            return noErr
        }, 1, &eventType, selfPtr, &handler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x534C4954) /* 'SLIT' */, id: 1)
        RegisterEventHotKey(keyCode, modifiers.rawValue, hotKeyID,
                            GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
