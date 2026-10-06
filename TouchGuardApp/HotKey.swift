import Carbon.HIToolbox

/// A system-wide hotkey via Carbon's `RegisterEventHotKey`, which needs no
/// extra permission. Only one hotkey per app is supported, which is all we need.
@MainActor
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// The default ⌃⌥⌘T toggle.
    nonisolated static let defaultKeyCode = UInt32(kVK_ANSI_T)
    nonisolated static let defaultModifiers = UInt32(controlKey | optionKey | cmdKey)

    init(keyCode: UInt32 = HotKey.defaultKeyCode,
         modifiers: UInt32 = HotKey.defaultModifiers,
         action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, refcon in
            guard let refcon else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.action() }
            return noErr
        }, 1, &eventType, refcon, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x5447_4B59) /* 'TGKY' */, id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
