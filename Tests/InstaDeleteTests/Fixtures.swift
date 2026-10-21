import ImageIO
import UniformTypeIdentifiers
import XCTest

enum Fixtures {
    /// A real 2×2 PNG.
    static let png: Data = {
        let ctx = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }()

    /// QuickTime/MP4 header: size + "ftyp" + brand.
    static let mov = Data([0x00, 0x00, 0x00, 0x14] + Array("ftypqt  ".utf8) + [0, 0, 0, 0] + Array("qt  ".utf8))

    /// Three 188-byte MPEG-TS packets.
    static let mpegTS: Data = {
        var d = Data(count: 188 * 3)
        for i in 0..<3 { d[i * 188] = 0x47 }
        return d
    }()

    static let typeScript = Data("import { x } from './y';\nexport const z = x + 1;\n".utf8)
}
