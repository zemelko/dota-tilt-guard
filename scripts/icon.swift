import AppKit
let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
}
func polygon(_ points: [(CGFloat, CGFloat)], _ fill: NSColor) {
    let path = NSBezierPath(); path.move(to: NSPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
    path.close(); fill.setFill(); path.fill()
}
let dark = color(0.065, 0.08, 0.095)
let tile = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 210, yRadius: 210)
NSGradient(starting: color(0.15, 0.19, 0.21), ending: dark)!.draw(in: tile, angle: -90)
// Original chat-and-rune artwork: a diagonal lane and two contrasting bases.
let red = color(0.83, 0.25, 0.19)
red.setFill()
NSBezierPath(roundedRect: NSRect(x: 176, y: 232, width: 626, height: 582), xRadius: 70, yRadius: 70).fill()
polygon([(176, 320), (176, 151), (367, 301)], red)
polygon([(269, 715), (335, 753), (713, 371), (653, 335)], dark)
polygon([(280, 535), (394, 398), (278, 411)], dark)
polygon([(567, 679), (704, 664), (709, 540)], dark)
let mint = color(0.55, 0.91, 0.77)
let shield = NSBezierPath()
shield.move(to: NSPoint(x: 739, y: 475)); shield.line(to: NSPoint(x: 887, y: 420))
shield.line(to: NSPoint(x: 870, y: 280))
shield.curve(to: NSPoint(x: 739, y: 151), controlPoint1: NSPoint(x: 858, y: 219), controlPoint2: NSPoint(x: 793, y: 176))
shield.curve(to: NSPoint(x: 608, y: 280), controlPoint1: NSPoint(x: 685, y: 176), controlPoint2: NSPoint(x: 620, y: 219))
shield.line(to: NSPoint(x: 591, y: 420)); shield.close()
dark.setStroke(); shield.lineWidth = 34; shield.lineJoinStyle = .round; shield.stroke()
mint.setFill(); shield.fill()
dark.setStroke()
let check = NSBezierPath(); check.move(to: NSPoint(x: 667, y: 324)); check.line(to: NSPoint(x: 722, y: 268)); check.line(to: NSPoint(x: 811, y: 374))
check.lineWidth = 31; check.lineCapStyle = .round; check.lineJoinStyle = .round; check.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
