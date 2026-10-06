import AppKit

enum AppBrand {
    /// A separate small-size mark keeps the diagonal rune and shield legible in the menu bar.
    static func menuIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            func polygon(_ points: [(CGFloat, CGFloat)]) {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: points[0].0, y: points[0].1))
                for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
                path.close(); path.fill()
            }
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 1, y: 4, width: 15, height: 15), xRadius: 1.5, yRadius: 1.5).fill()
            context.saveGState(); context.setBlendMode(.clear)
            polygon([(3, 17), (5, 18), (14, 7), (12, 6)])
            polygon([(3, 12), (6.5, 7), (3, 8)])
            polygon([(10, 16), (14, 15), (14, 11)])
            // Clear a gap between the two silhouettes, including under the shield.
            polygon([(15.5, 14), (22, 11.5), (21, 4), (15.5, 0), (10, 4), (9, 11.5)])
            context.restoreGState()
            polygon([(15.5, 12.5), (20.5, 10.5), (19.7, 4.8), (15.5, 1.7), (11.3, 4.8), (10.5, 10.5)])
            context.saveGState(); context.setBlendMode(.clear)
            let check = NSBezierPath()
            check.move(to: NSPoint(x: 12.9, y: 7.7)); check.line(to: NSPoint(x: 15, y: 5.6)); check.line(to: NSPoint(x: 18.3, y: 9.1))
            check.lineWidth = 1.5; check.lineCapStyle = .round; check.lineJoinStyle = .round
            NSColor.black.setStroke(); check.stroke()
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Dota Tilt Guard"
        return image
    }
}
