import AppKit
import Foundation

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext
let rect = CGRect(origin: .zero, size: size)

let cornerRadius: CGFloat = 220
let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(path)
ctx.clip()

let colors = [
    NSColor(red: 0.32, green: 0.10, blue: 0.55, alpha: 1.0).cgColor,
    NSColor(red: 0.18, green: 0.05, blue: 0.30, alpha: 1.0).cgColor
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors as CFArray,
                          locations: [0.0, 1.0])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: size.height),
                       end: CGPoint(x: size.width, y: 0),
                       options: [])

let highlight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [
                               NSColor(white: 1.0, alpha: 0.25).cgColor,
                               NSColor(white: 1.0, alpha: 0.0).cgColor
                           ] as CFArray,
                           locations: [0.0, 1.0])!
ctx.drawRadialGradient(highlight,
                       startCenter: CGPoint(x: size.width * 0.3, y: size.height * 0.85),
                       startRadius: 0,
                       endCenter: CGPoint(x: size.width * 0.3, y: size.height * 0.85),
                       endRadius: size.width * 0.6,
                       options: [])

let emoji = "🚩"
let fontSize: CGFloat = 640
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: fontSize)
]
let str = NSAttributedString(string: emoji, attributes: attrs)
let strSize = str.size()
str.draw(at: NSPoint(x: (size.width - strSize.width) / 2 + 50,
                     y: (size.height - strSize.height) / 2 + 60))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: outURL)
print("wrote \(outURL.path)")
