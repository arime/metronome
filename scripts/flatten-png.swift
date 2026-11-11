// Rewrites each PNG given as an argument without its alpha channel, in place.
// App Store Connect rejects screenshots with transparency, and the simulator's
// screenshots carry an alpha channel even though every pixel is opaque.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

var failed = false
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          )
    else {
        print("Could not read \(path)")
        failed = true
        continue
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let opaque = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        print("Could not write \(path)")
        failed = true
        continue
    }
    CGImageDestinationAddImage(destination, opaque, nil)
    if !CGImageDestinationFinalize(destination) {
        print("Could not write \(path)")
        failed = true
    }
}
exit(failed ? 1 : 0)
