// Rivet Rise app icon: a tower crane's hook lowering a hi-vis floor module onto a riveted
// tower against a dawn sky. Pure CoreGraphics, no assets.
// Usage: swift make_icons.swift <output-directory>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: locations)!
}

let ink = rgb(0x1F1B16)

func draw(size: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let s = CGFloat(size) / 1024
    // Work in a 1024 top-left space.
    ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: s, y: -s)
    ctx.setLineJoin(.round); ctx.setLineCap(.round)

    func fillRect(_ r: CGRect, _ c: CGColor) { ctx.setFillColor(c); ctx.fill(r) }
    func outline(_ path: CGPath, _ w: CGFloat = 12) { ctx.addPath(path); ctx.setStrokeColor(ink); ctx.setLineWidth(w); ctx.strokePath() }
    func vgrad(_ path: CGPath, _ cols: [CGColor], _ y0: CGFloat, _ y1: CGFloat) {
        ctx.saveGState(); ctx.addPath(path); ctx.clip()
        ctx.drawLinearGradient(gradient(cols), start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    // Dawn sky.
    vgrad(CGPath(rect: CGRect(x: 0, y: 0, width: 1024, height: 1024), transform: nil),
          [rgb(0x2F7F9C), rgb(0x7FBBC0), rgb(0xF6C59A), rgb(0xF29C6B)], 0, 1024)
    // Sun glow.
    ctx.saveGState(); ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([rgb(0xFFE6B5, 0.95), rgb(0xFFE6B5, 0)]), startCenter: CGPoint(x: 760, y: 820), startRadius: 0, endCenter: CGPoint(x: 760, y: 820), endRadius: 360, options: [])
    ctx.restoreGState()
    // Distant skyline.
    var x: CGFloat = -10
    var seed: UInt64 = 7
    while x < 1040 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let w = 50 + CGFloat(seed >> 58) * 3
        let h = 120 + CGFloat((seed >> 40) & 0xFF)
        fillRect(CGRect(x: x, y: 1024 - h, width: w, height: h), rgb(0x5B5A6E, 0.8))
        x += w + 6
    }

    // Tower: four floors, alternating tenants, riveted beams between them.
    let floorColors: [UInt32] = [0x3F7FA8, 0xE09468, 0x5FA88A, 0x3F7FA8, 0xE09468]
    let floorH: CGFloat = 110
    for i in 0..<4 {
        let y = 1024 - CGFloat(i + 1) * floorH + 20
        let r = CGRect(x: 312, y: y, width: 400, height: floorH)
        let path = CGPath(rect: r, transform: nil)
        vgrad(path, [rgb(floorColors[i]), rgb(floorColors[i], 0.85)], r.minY, r.maxY)
        for k in 0..<4 {
            let wr = CGRect(x: r.minX + 30 + CGFloat(k) * 92, y: r.minY + 34, width: 60, height: 52)
            fillRect(wr, ink)
            fillRect(wr.insetBy(dx: 7, dy: 7), (i + k) % 3 == 0 ? rgb(0xFFD877) : rgb(0xBFE6F2))
        }
        fillRect(CGRect(x: r.minX - 6, y: r.minY, width: r.width + 12, height: 22), rgb(0x343841))
        for k in 0..<7 {
            let c = CGRect(x: r.minX + 18 + CGFloat(k) * 60, y: r.minY + 5, width: 12, height: 12)
            ctx.setFillColor(rgb(0xB9C1CA)); ctx.fillEllipse(in: c)
        }
        outline(path, 10)
    }

    // Crane jib across the top.
    let jibTop: CGFloat = 92, jibBottom: CGFloat = 176
    let diag = CGMutablePath()
    var jx: CGFloat = -40
    var up = true
    while jx < 1060 {
        diag.move(to: CGPoint(x: jx, y: up ? jibBottom : jibTop)); diag.addLine(to: CGPoint(x: jx + 70, y: up ? jibTop : jibBottom))
        up.toggle(); jx += 70
    }
    ctx.addPath(diag); ctx.setStrokeColor(ink); ctx.setLineWidth(26); ctx.strokePath()
    ctx.addPath(diag); ctx.setStrokeColor(rgb(0xF5C21C)); ctx.setLineWidth(14); ctx.strokePath()
    for y in [jibTop, jibBottom] {
        let chord = CGPath(rect: CGRect(x: -20, y: y - 12, width: 1064, height: 24), transform: nil)
        ctx.addPath(chord); ctx.setFillColor(rgb(0xF5C21C)); ctx.fillPath()
        outline(chord, 9)
    }

    // Cable, hook block and the module being lowered.
    fillRect(CGRect(x: 535, y: 188, width: 10, height: 150), ink)
    let block = CGPath(roundedRect: CGRect(x: 494, y: 300, width: 92, height: 80), cornerWidth: 14, cornerHeight: 14, transform: nil)
    ctx.addPath(block); ctx.setFillColor(rgb(0xF5C21C)); ctx.fillPath(); outline(block, 10)
    ctx.saveGState(); ctx.addPath(block); ctx.clip()
    for k in 0..<6 { let p = CGMutablePath(); p.addLines(between: [CGPoint(x: 480 + CGFloat(k) * 30, y: 380), CGPoint(x: 500 + CGFloat(k) * 30, y: 340), CGPoint(x: 514 + CGFloat(k) * 30, y: 340), CGPoint(x: 494 + CGFloat(k) * 30, y: 380)]); ctx.addPath(p); ctx.setFillColor(ink); ctx.fillPath() }
    ctx.restoreGState()
    // Slings to the module.
    ctx.setStrokeColor(ink); ctx.setLineWidth(10)
    ctx.move(to: CGPoint(x: 540, y: 380)); ctx.addLine(to: CGPoint(x: 340, y: 440)); ctx.strokePath()
    ctx.move(to: CGPoint(x: 540, y: 380)); ctx.addLine(to: CGPoint(x: 740, y: 440)); ctx.strokePath()
    let module = CGRect(x: 300, y: 440, width: 460, height: 112)
    let mpath = CGPath(rect: module, transform: nil)
    vgrad(mpath, [rgb(0xFFE07A), rgb(0xF5C21C), rgb(0xC9940A)], module.minY, module.maxY)
    fillRect(CGRect(x: module.minX, y: module.minY, width: module.width, height: 22), rgb(0x343841))
    for k in 0..<5 {
        let wr = CGRect(x: module.minX + 28 + CGFloat(k) * 86, y: module.minY + 38, width: 58, height: 52)
        fillRect(wr, ink)
        fillRect(wr.insetBy(dx: 7, dy: 7), rgb(0xBFE6F2))
    }
    outline(mpath, 12)

    // Rivet sparkle at the top joint of the tower.
    let spark = CGPoint(x: 712, y: 1024 - 4 * floorH + 20)
    ctx.saveGState(); ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([rgb(0xFFF4C0, 1), rgb(0xFFB040, 0.6), rgb(0xFF8020, 0)]), startCenter: spark, startRadius: 0, endCenter: spark, endRadius: 120, options: [])
    ctx.restoreGState()
    let star = CGMutablePath()
    for i in 0..<16 {
        let a = CGFloat(i) * .pi / 8
        let r: CGFloat = i % 2 == 0 ? 70 : 16
        let p = CGPoint(x: spark.x + cos(a) * r, y: spark.y + sin(a) * r)
        if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
    }
    star.closeSubpath()
    ctx.addPath(star); ctx.setFillColor(rgb(0xFFF6D0)); ctx.fillPath()
    return ctx
}

func save(_ ctx: CGContext, _ url: URL) {
    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.path)")
}

for size in [512, 1024] {
    save(draw(size: size), outputDirectory.appendingPathComponent("RivetRise-\(size).png"))
}
