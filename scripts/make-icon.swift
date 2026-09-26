import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)]
for (name, size) in sizes {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(size)/1024, y: CGFloat(size)/1024)
    context.setFillColor(CGColor(red: 0.21, green: 0.40, blue: 0.29, alpha: 1))
    context.addPath(CGPath(roundedRect: CGRect(x: 50, y: 50, width: 924, height: 924), cornerWidth: 204, cornerHeight: 204, transform: nil)); context.fillPath()
    for (x, y, wide) in [(228,542,220),(496,542,300),(228,250,220),(496,250,300)] {
        context.setFillColor(CGColor(red: 0.88, green: 0.94, blue: 0.86, alpha: (x == 228 && y == 542) ? 1 : 0.60))
        context.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: wide, height: 238), cornerWidth: 44, cornerHeight: 44, transform: nil)); context.fillPath()
    }
    let url = destination.appendingPathComponent(name + ".png")
    let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(imageDestination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(imageDestination) else { fatalError("Icon export failed") }
}
