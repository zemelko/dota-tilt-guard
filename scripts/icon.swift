import AppKit
let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.065, green: 0.08, blue: 0.095, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 215, yRadius: 215).fill()
let mint = NSColor(calibratedRed: 0.55, green: 0.91, blue: 0.77, alpha: 1)
mint.setFill()
NSBezierPath(roundedRect: NSRect(x: 215, y: 285, width: 594, height: 455), xRadius: 118, yRadius: 118).fill()
let tail = NSBezierPath()
tail.move(to: NSPoint(x: 275, y: 330)); tail.line(to: NSPoint(x: 275, y: 185)); tail.line(to: NSPoint(x: 455, y: 330)); tail.close(); tail.fill()
NSColor(calibratedRed: 0.07, green: 0.20, blue: 0.16, alpha: 1).setStroke()
let check = NSBezierPath()
check.move(to: NSPoint(x: 363, y: 515)); check.line(to: NSPoint(x: 463, y: 422)); check.line(to: NSPoint(x: 665, y: 615))
check.lineWidth = 50; check.lineCapStyle = .round; check.lineJoinStyle = .round; check.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
