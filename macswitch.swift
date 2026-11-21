import ApplicationServices
import Carbon
import Cocoa
import ServiceManagement

// Key codes of the number row 1...9 -> index in the layout list.
let digitIndex: [Int64: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8]
let blockingFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

var eventTap: CFMachPort?

func enabledLayouts() -> [TISInputSource] {
    let filter = [
        kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
        kTISPropertyInputSourceIsSelectCapable as String: true,
    ] as CFDictionary
    let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource]
    return list ?? []
}

func layoutName(_ source: TISInputSource) -> String {
    guard let raw = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return "?" }
    return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
}

func sourceID(_ source: TISInputSource) -> String {
    guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
    return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
}

// Layout IDs for fn+1...fn+9. Uses the saved choice, else the system order.
let slotsKey = "slots"

func currentSlots() -> [String] {
    if let saved = UserDefaults.standard.stringArray(forKey: slotsKey), saved.count == 9 { return saved }
    let ids = enabledLayouts().map(sourceID)
    return (0..<9).map { $0 < ids.count ? ids[$0] : "" }
}

func assignedLayout(forSlot index: Int) -> TISInputSource? {
    let id = currentSlots()[index]
    return enabledLayouts().first { sourceID($0) == id }
}

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    guard
        event.flags.contains(.maskSecondaryFn),
        event.flags.isDisjoint(with: blockingFlags),
        let index = digitIndex[keyCode]
    else { return Unmanaged.passUnretained(event) }

    if type == .keyDown, let layout = assignedLayout(forSlot: index) { TISSelectInputSource(layout) }
    return nil // swallow fn+digit so no "1" is typed
}

func startTap() -> Bool {
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: nil
    ) else { return false }
    eventTap = tap

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "MacSwitch")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Shows the system permission prompt once, then waits until access is granted.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if !startTap() {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
                if startTap() { timer.invalidate() }
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let layouts = enabledLayouts()
        let slots = currentSlots()
        for index in 0..<min(9, layouts.count) {
            let assigned = layouts.first { sourceID($0) == slots[index] }
            let row = menu.addItem(withTitle: "fn + \(index + 1)   \(assigned.map(layoutName) ?? "—")", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for layout in layouts {
                let item = submenu.addItem(withTitle: layoutName(layout), action: #selector(assignLayout(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.representedObject = sourceID(layout)
                item.state = sourceID(layout) == slots[index] ? .on : .off
            }
            row.submenu = submenu
        }
        let reset = menu.addItem(withTitle: "Reset to system order", action: #selector(resetOrder), keyEquivalent: "")
        reset.target = self
        menu.addItem(.separator())
        if eventTap == nil {
            let grant = menu.addItem(withTitle: "Grant Accessibility access…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            grant.target = self
        }
        let login = menu.addItem(withTitle: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(withTitle: "Quit MacSwitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func assignLayout(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        var slots = currentSlots()
        slots[sender.tag] = id
        UserDefaults.standard.set(slots, forKey: slotsKey)
    }

    @objc private func resetOrder() {
        UserDefaults.standard.removeObject(forKey: slotsKey)
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
