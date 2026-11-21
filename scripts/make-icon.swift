import Cocoa

// Draws the app icon (1024x1024 PNG). Usage: make-icon <out.png>
guard CommandLine.arguments.count == 2 else {
    print("usage: make-icon <out.png>")
    exit(1)
}

let canvas: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 24
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.set()
NSColor.black.setFill()
body.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(
    starting: NSColor(red: 0.36, green: 0.42, blue: 0.98, alpha: 1),
    ending: NSColor(red: 0.12, green: 0.14, blue: 0.45, alpha: 1)
)?.draw(in: body, angle: -90)

let symbolConfig = NSImage.SymbolConfiguration(pointSize: 400, weight: .medium)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let globe = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfig) {
    let size = globe.size
    globe.draw(in: NSRect(x: (canvas - size.width) / 2, y: 440, width: size.width, height: size.height))
}

let label = NSAttributedString(string: "fn", attributes: [
    .font: NSFont.systemFont(ofSize: 210, weight: .heavy),
    .foregroundColor: NSColor.white.withAlphaComponent(0.92),
])
let labelSize = label.size()
label.draw(at: NSPoint(x: (canvas - labelSize.width) / 2, y: 190))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
