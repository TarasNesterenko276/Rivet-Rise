// Rivet Rise art generator.
// Paints every bitmap the app uses (floor modules, crane parts, skies, the building site,
// foremen, upgrade loads, manual illustrations, HUD parts, stickers) with CoreGraphics
// and writes them as @3x image sets into an asset catalog folder.
// Deterministic: the same run always produces the same art.
//
// Usage: swift generate_assets.swift "<path>/Assets.xcassets/Generated" [preview-dir]

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Generated")
let previewRoot: URL? = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
let fm = FileManager.default
try? fm.createDirectory(at: outputRoot, withIntermediateDirectories: true)
if let previewRoot { try? fm.createDirectory(at: previewRoot, withIntermediateDirectories: true) }
try! #"{"info":{"author":"xcode","version":1}}"#.write(to: outputRoot.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Colour helpers

struct Col {
    var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1
    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(hex: UInt32, _ a: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255; self.a = a
    }
    var cg: CGColor { CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])! }
    func mix(_ o: Col, _ t: CGFloat) -> Col { Col(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t) }
    func alpha(_ v: CGFloat) -> Col { Col(r, g, b, v) }
    func lighter(_ t: CGFloat) -> Col { mix(.white, t) }
    func darker(_ t: CGFloat) -> Col { mix(Col(0.07, 0.06, 0.05), t) }
    static let white = Col(1, 1, 1)
}

// Palette (mirrors Theme.Colors in the app).
let ink = Col(hex: 0x1F1B16)
let hiVis = Col(hex: 0xF5C21C)
let hiVisDeep = Col(hex: 0xC9940A)
let asphalt = Col(hex: 0x23262B)
let graphite = Col(hex: 0x343841)
let concrete = Col(hex: 0xBAB5AD)
let concreteLight = Col(hex: 0xDEDBD3)
let rust = Col(hex: 0xC4552B)
let steel = Col(hex: 0x4C6B86)
let skyTeal = Col(hex: 0x3FA6B5)
let skyPeach = Col(hex: 0xF6C59A)
let manila = Col(hex: 0xEADBB8)
let kraft = Col(hex: 0xC89B62)
let safetyGreen = Col(hex: 0x3E9B5A)
let alarm = Col(hex: 0xD23A2C)
let lamp = Col(hex: 0xFFE08C)

struct Rng {
    var s: UInt64
    mutating func next() -> CGFloat {
        s ^= s >> 12; s ^= s << 25; s ^= s >> 27
        return CGFloat(Double((s &* 2685821657736338717) >> 11) / Double(1 << 53))
    }
    mutating func r(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

// MARK: - Canvas (top-left origin, drawing in points, written at 3x)

var ctx: CGContext!
var W: CGFloat = 0, H: CGFloat = 0
let scale: CGFloat = 3

func begin(_ w: CGFloat, _ h: CGFloat) {
    W = w; H = h
    ctx = CGContext(data: nil, width: Int(w * scale), height: Int(h * scale), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: h * scale); ctx.scaleBy(x: scale, y: -scale)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.interpolationQuality = .high
}

func finish(_ name: String) {
    let image = ctx.makeImage()!
    let dir = outputRoot.appendingPathComponent("\(name).imageset")
    try? fm.removeItem(at: dir)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("\(name).png")
    let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
    let json = #"{"images":[{"idiom":"universal","scale":"1x"},{"idiom":"universal","scale":"2x"},{"filename":"\#(name).png","idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}"#
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    if let previewRoot { try? fm.removeItem(at: previewRoot.appendingPathComponent("\(name).png")); try? fm.copyItem(at: file, to: previewRoot.appendingPathComponent("\(name).png")) }
    print("✓ \(name)")
}

func canvas(_ name: String, _ w: CGFloat, _ h: CGFloat, _ draw: () -> Void) { begin(w, h); draw(); finish(name) }

func gradient(_ cols: [Col], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: cols.map(\.cg) as CFArray, locations: locs)!
}

func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func rect(_ r: CGRect) -> CGPath { CGPath(rect: r, transform: nil) }
func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: min(radius, r.width / 2), cornerHeight: min(radius, r.height / 2), transform: nil) }
func ellipse(_ r: CGRect) -> CGPath { CGPath(ellipseIn: r, transform: nil) }
func circle(_ c: CGPoint, _ rad: CGFloat) -> CGPath { ellipse(CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)) }
func poly(_ pts: [CGPoint]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p }
func line(_ a: CGPoint, _ b: CGPoint) -> CGPath { let p = CGMutablePath(); p.move(to: a); p.addLine(to: b); return p }

func fill(_ path: CGPath, _ c: Col) { ctx.addPath(path); ctx.setFillColor(c.cg); ctx.fillPath() }
func stroke(_ path: CGPath, _ c: Col, _ w: CGFloat) { ctx.addPath(path); ctx.setStrokeColor(c.cg); ctx.setLineWidth(w); ctx.strokePath() }
func vfill(_ path: CGPath, _ cols: [Col], _ locs: [CGFloat]? = nil) {
    let b = path.boundingBox
    lfill(path, cols, P(0, b.minY), P(0, b.maxY), locs)
}
func lfill(_ path: CGPath, _ cols: [Col], _ from: CGPoint, _ to: CGPoint, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(gradient(cols, locs), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
func rfill(_ path: CGPath, _ cols: [Col], _ c: CGPoint, _ radius: CGFloat, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawRadialGradient(gradient(cols, locs), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}
func glow(_ c: CGPoint, _ radius: CGFloat, _ col: Col) {
    ctx.saveGState(); ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([col, col.alpha(0)]), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    ctx.restoreGState()
}
func shadowed(_ offsetY: CGFloat, _ blur: CGFloat, _ col: Col = Col(0.08, 0.06, 0.04, 0.38), _ body: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: offsetY * 0.4 * scale, height: -offsetY * scale), blur: blur * scale, color: col.cg); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer(); ctx.restoreGState()
}
func clipped(_ path: CGPath, _ body: () -> Void) { ctx.saveGState(); ctx.addPath(path); ctx.clip(); body(); ctx.restoreGState() }

/// Draws a filled shape with the house style: gradient lit from the top-left, then a dark ink outline.
func part(_ path: CGPath, _ base: Col, outline: CGFloat = 2.2, light: CGFloat = 0.28, dark: CGFloat = 0.22) {
    let b = path.boundingBox
    lfill(path, [base.lighter(light), base, base.darker(dark)], P(b.minX, b.minY), P(b.minX + b.width * 0.35, b.maxY), [0, 0.45, 1])
    if outline > 0 { stroke(path, ink, outline) }
}

func text(_ s: String, _ p: CGPoint, size: CGFloat, font: String = "HelveticaNeue-CondensedBlack", color: Col, kern: CGFloat = 0, center: Bool = true) {
    let f = NSFont(name: font, size: size) ?? NSFont.systemFont(ofSize: size, weight: .black)
    let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: NSColor(cgColor: color.cg)!, .kern: kern]
    let str = NSAttributedString(string: s, attributes: attrs)
    let sz = str.size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    str.draw(at: CGPoint(x: center ? p.x - sz.width / 2 : p.x, y: p.y - sz.height / 2))
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Shared motifs

func rivet(_ c: CGPoint, _ rad: CGFloat, _ base: Col = Col(hex: 0x8C949E)) {
    rfill(circle(c, rad), [base.lighter(0.6), base, base.darker(0.4)], P(c.x - rad * 0.4, c.y - rad * 0.4), rad * 1.6)
    stroke(circle(c, rad), ink.alpha(0.7), max(0.6, rad * 0.3))
}

/// Yellow and black hazard stripes inside a rectangle.
func hazard(_ r: CGRect, width w: CGFloat = 10, a: Col = hiVis, b: Col = ink) {
    clipped(rect(r)) {
        fill(rect(r), a)
        var x = r.minX - r.height
        while x < r.maxX + r.height {
            fill(poly([P(x, r.maxY), P(x + w, r.maxY), P(x + w + r.height, r.minY), P(x + r.height, r.minY)]), b)
            x += w * 2
        }
    }
}

/// A horizontal steel I-beam.
func beam(_ r: CGRect, _ base: Col = graphite, rivets: Bool = true) {
    part(rect(r), base, outline: 1.6, light: 0.35, dark: 0.3)
    fill(rect(R(r.minX, r.minY + r.height * 0.18, r.width, max(1, r.height * 0.12))), Col.white.alpha(0.18))
    if rivets {
        var x = r.minX + 8
        while x < r.maxX - 4 { rivet(P(x, r.midY), r.height * 0.18); x += 16 }
    }
}

/// Lattice truss between two horizontal lines (crane jib, mast sections).
func truss(_ r: CGRect, _ base: Col = hiVis, bay: CGFloat = 26, chord: CGFloat = 4, web: CGFloat = 2.4) {
    var x = r.minX
    let diag = CGMutablePath()
    var up = true
    while x < r.maxX - 0.5 {
        let nx = min(x + bay, r.maxX)
        diag.move(to: P(x, up ? r.maxY : r.minY)); diag.addLine(to: P(nx, up ? r.minY : r.maxY))
        up.toggle(); x = nx
    }
    stroke(diag, ink, web + 2)
    stroke(diag, base.darker(0.1), web)
    for y in [r.minY, r.maxY] {
        let c = rect(R(r.minX, y - chord / 2, r.width, chord))
        fill(c, base); stroke(c, ink, 1.4)
    }
}

/// A vertical lattice mast.
func mast(_ r: CGRect, _ base: Col = hiVis, bay: CGFloat = 24) {
    let diag = CGMutablePath()
    var y = r.minY; var left = true
    while y < r.maxY - 0.5 {
        let ny = min(y + bay, r.maxY)
        diag.move(to: P(left ? r.minX : r.maxX, y)); diag.addLine(to: P(left ? r.maxX : r.minX, ny))
        left.toggle(); y = ny
    }
    stroke(diag, ink, 4.4); stroke(diag, base.darker(0.12), 2.4)
    for x in [r.minX, r.maxX] {
        let c = rect(R(x - 2.5, r.minY, 5, r.height))
        lfill(c, [base.lighter(0.3), base, base.darker(0.3)], P(x - 2.5, 0), P(x + 2.5, 0)); stroke(c, ink, 1.4)
    }
}

/// A soft cumulus: shadow copy offset below, lit body on top. Never outlines the union.
func cloud(_ r: CGRect, seed: UInt64, top: Col = .white, under: Col = Col(hex: 0xE9C9B8), alpha: CGFloat = 1) {
    var g = Rng(s: seed)
    let p = CGMutablePath()
    p.addPath(rr(R(r.minX + r.width * 0.06, r.midY, r.width * 0.88, r.height * 0.42), r.height * 0.2))
    let puffs = 5
    for i in 0..<puffs {
        let t = (CGFloat(i) + 0.5) / CGFloat(puffs)
        let rad = r.height * g.r(0.26, 0.42) * (1 - abs(t - 0.5) * 0.7)
        p.addPath(circle(P(r.minX + r.width * (0.12 + 0.76 * t), r.midY + r.height * 0.1 - rad * g.r(0.3, 0.8)), rad))
    }
    ctx.saveGState(); ctx.translateBy(x: 0, y: r.height * 0.08)
    fill(p, under.alpha(alpha * 0.9))
    ctx.restoreGState()
    clipped(p) { ctx.translateBy(x: 0, y: -r.height * 0.06); vfill(p, [top.alpha(alpha), top.mix(under, 0.35).alpha(alpha)]) }
}

/// Distant skyline silhouette with optional lit windows.
func skyline(_ baseY: CGFloat, _ col: Col, lit: Col?, seed: UInt64, maxH: CGFloat, minW: CGFloat = 26, maxW: CGFloat = 60) {
    var g = Rng(s: seed)
    var x: CGFloat = -10
    while x < W + 10 {
        let w = g.r(minW, maxW), h = g.r(maxH * 0.35, maxH)
        fill(rect(R(x, baseY - h, w, h + 400)), col)
        if g.next() > 0.7 { fill(rect(R(x + w * 0.45, baseY - h - g.r(8, 24), 2, 30)), col) }
        if let lit {
            var yy = baseY - h + 8
            while yy < baseY - 4 {
                var xx = x + 5
                while xx < x + w - 6 { if g.next() > 0.6 { fill(rect(R(xx, yy, 3.5, 4.5)), lit) }; xx += 8 }
                yy += 10
            }
        }
        x += w + g.r(2, 8)
    }
}

// MARK: - Floor modules (300 x 90 pt, cropped — never stretched — when trimmed)

let floorW: CGFloat = 300, floorH: CGFloat = 90

func floorFrame(_ infill: () -> Void, slab: Col = concrete, columns: Col = graphite) {
    let body = R(0, 0, floorW, floorH)
    clipped(rect(body)) {
        infill()
        // Columns.
        for i in 0...6 {
            let x = CGFloat(i) * floorW / 6
            let c = rect(R(x - 4, 10, 8, floorH - 20))
            lfill(c, [columns.lighter(0.3), columns, columns.darker(0.3)], P(x - 4, 0), P(x + 4, 0))
            stroke(c, ink.alpha(0.8), 1.2)
        }
    }
    // Top beam with rivets and bottom slab.
    beam(R(0, 0, floorW, 11), columns)
    let slabRect = R(0, floorH - 13, floorW, 13)
    part(rect(slabRect), slab, outline: 0, light: 0.3, dark: 0.25)
    fill(rect(R(0, floorH - 13, floorW, 2)), Col.white.alpha(0.35))
    stroke(rect(body.insetBy(dx: 0.8, dy: 0.8)), ink, 1.6)
}

func window(_ r: CGRect, glass: Col, lit: Bool, curtain: Col? = nil) {
    fill(rect(r), ink.alpha(0.85))
    let g = r.insetBy(dx: 2, dy: 2)
    if lit {
        vfill(rect(g), [Col(hex: 0xFFF2BF), Col(hex: 0xFFC860), Col(hex: 0xF09A3E)])
    } else {
        lfill(rect(g), [glass.lighter(0.45), glass, glass.darker(0.35)], P(g.minX, g.minY), P(g.maxX, g.maxY))
        clipped(rect(g)) { fill(poly([P(g.minX, g.maxY), P(g.minX + g.width * 0.5, g.minY), P(g.minX + g.width * 0.75, g.minY), P(g.minX + g.width * 0.25, g.maxY)]), Col.white.alpha(0.3)) }
    }
    if let curtain {
        fill(poly([P(g.minX, g.minY), P(g.minX + g.width * 0.32, g.minY), P(g.minX + g.width * 0.14, g.maxY), P(g.minX, g.maxY)]), curtain)
        fill(poly([P(g.maxX, g.minY), P(g.maxX - g.width * 0.32, g.minY), P(g.maxX - g.width * 0.14, g.maxY), P(g.maxX, g.maxY)]), curtain)
    }
    fill(rect(R(r.minX - 1, r.maxY - 1, r.width + 2, 3)), concreteLight)
}

func residentialFloor() {
    floorFrame({
        var g = Rng(s: 11)
        vfill(rect(R(0, 0, floorW, floorH)), [Col(hex: 0xE9A27A), Col(hex: 0xC9714D)])
        // Brick courses.
        var y: CGFloat = 14
        var row = 0
        while y < floorH - 12 {
            stroke(line(P(0, y), P(floorW, y)), Col(hex: 0x9A4E33, 0.35), 0.8)
            var x: CGFloat = row % 2 == 0 ? 0 : 7
            while x < floorW { stroke(line(P(x, y), P(x, y + 6)), Col(hex: 0x9A4E33, 0.3), 0.8); x += 14 }
            y += 6; row += 1
        }
        let curtains = [Col(hex: 0x3E9B5A), Col(hex: 0xD23A2C), Col(hex: 0x4C6B86), Col(hex: 0xF5C21C)]
        for i in 0..<6 {
            let cx = CGFloat(i) * 50 + 25
            window(R(cx - 13, 22, 26, 34), glass: Col(hex: 0x7FB3D6), lit: g.next() > 0.55, curtain: curtains[i % 4].alpha(0.9))
            // Balcony rail.
            let rail = R(cx - 17, 56, 34, 12)
            fill(rect(rail), Col(hex: 0xF1EEE6, 0.25))
            stroke(rect(rail), ink.alpha(0.8), 1.2)
            for k in 1..<5 { stroke(line(P(rail.minX + CGFloat(k) * rail.width / 5, rail.minY), P(rail.minX + CGFloat(k) * rail.width / 5, rail.maxY)), ink.alpha(0.6), 1) }
            if g.next() > 0.6 { fill(circle(P(cx + 10, 54), 4), safetyGreen) }
        }
    })
}

func officeFloor() {
    floorFrame({
        lfill(rect(R(0, 0, floorW, floorH)), [Col(hex: 0x9ED6EA), Col(hex: 0x3F7FA8), Col(hex: 0x24496B)], P(0, 0), P(floorW * 0.3, floorH))
        var g = Rng(s: 21)
        for i in 0..<12 {
            let x = CGFloat(i) * 25
            stroke(line(P(x, 0), P(x, floorH)), Col(hex: 0x1D3346), 1.6)
            if g.next() > 0.5 { fill(rect(R(x + 3, 20, 19, 44)), Col(hex: 0xFFE7A3, 0.55)) }
        }
        stroke(line(P(0, 44), P(floorW, 44)), Col(hex: 0x1D3346), 1.4)
        for k in 0..<4 {
            let x = CGFloat(k) * 85 + 10
            fill(poly([P(x, floorH), P(x + 40, 0), P(x + 58, 0), P(x + 18, floorH)]), Col.white.alpha(0.16))
        }
    }, columns: Col(hex: 0x2C3440))
}

func gardenFloor() {
    floorFrame({
        vfill(rect(R(0, 0, floorW, floorH)), [Col(hex: 0xBFE3D2), Col(hex: 0x86C3A6)])
        var g = Rng(s: 31)
        // Glass back wall.
        for i in 0..<10 { stroke(line(P(CGFloat(i) * 30 + 15, 12), P(CGFloat(i) * 30 + 15, 60)), Col(hex: 0x5B9A80, 0.6), 1) }
        // Trees and shrubs.
        for i in 0..<7 {
            let cx = CGFloat(i) * 44 + 18 + g.r(-4, 4)
            let h = g.r(28, 46)
            fill(rect(R(cx - 2, floorH - 22 - h * 0.5, 4, h * 0.5)), Col(hex: 0x6B4A2E))
            let crown = CGMutablePath()
            crown.addPath(circle(P(cx, floorH - 22 - h * 0.6), h * 0.32))
            crown.addPath(circle(P(cx - h * 0.2, floorH - 22 - h * 0.42), h * 0.24))
            crown.addPath(circle(P(cx + h * 0.2, floorH - 22 - h * 0.42), h * 0.24))
            ctx.saveGState(); ctx.translateBy(x: 1.5, y: 2); fill(crown, Col(hex: 0x1F5A33)); ctx.restoreGState()
            clipped(crown) { lfill(crown, [Col(hex: 0x9AD86A), Col(hex: 0x3E9B5A), Col(hex: 0x2A7342)], P(cx - h * 0.4, floorH - 22 - h), P(cx + h * 0.2, floorH - 22)) }
        }
        // Planters.
        let planter = R(0, floorH - 24, floorW, 11)
        part(rect(planter), Col(hex: 0x8A6A4A), outline: 1.2)
        for i in 0..<15 { fill(circle(P(CGFloat(i) * 20 + 10, floorH - 25), 5), Col(hex: i % 3 == 0 ? 0xF5C21C : 0x4FAE6A)) }
    }, slab: Col(hex: 0xA8A49B))
}

func penthouseFloor() {
    floorFrame({
        vfill(rect(R(0, 0, floorW, floorH)), [Col(hex: 0xFFF3D6), Col(hex: 0xE8D2A2)])
        var g = Rng(s: 41)
        for i in 0..<5 {
            let cx = CGFloat(i) * 60 + 30
            let arch = CGMutablePath()
            arch.move(to: P(cx - 16, 70)); arch.addLine(to: P(cx - 16, 34))
            arch.addArc(center: P(cx, 34), radius: 16, startAngle: .pi, endAngle: 0, clockwise: false)
            arch.addLine(to: P(cx + 16, 70)); arch.closeSubpath()
            fill(arch, ink.alpha(0.85))
            let inner = arch.copy(strokingWithWidth: 0, lineCap: .round, lineJoin: .round, miterLimit: 1)
            _ = inner
            ctx.saveGState(); ctx.translateBy(x: cx, y: 52); ctx.scaleBy(x: 0.82, y: 0.88); ctx.translateBy(x: -cx, y: -52)
            if g.next() > 0.3 { vfill(arch, [Col(hex: 0xFFF4C8), Col(hex: 0xFFC35A)]) } else { vfill(arch, [Col(hex: 0xB5DDF2), Col(hex: 0x5D93BE)]) }
            ctx.restoreGState()
            stroke(line(P(cx, 22), P(cx, 70)), Col(hex: 0x9A7B3A), 1.2)
        }
        // Gold cornice band.
        let band = R(0, 12, floorW, 7)
        lfill(rect(band), [Col(hex: 0xFFE38A), Col(hex: 0xC99325)], P(0, band.minY), P(0, band.maxY))
        for i in 0..<30 { fill(circle(P(CGFloat(i) * 10 + 5, 15.5), 1.6), Col(hex: 0x8C6418)) }
    }, slab: Col(hex: 0xD9C8A2), columns: Col(hex: 0xB08A3A))
}

func girderFloor() {
    let body = R(0, 0, floorW, floorH)
    clipped(rect(body)) {
        fill(rect(body), Col(0, 0, 0, 0))
        // Diagonal bracing.
        let diag = CGMutablePath()
        for i in 0..<6 {
            let x = CGFloat(i) * 50
            diag.move(to: P(x, 12)); diag.addLine(to: P(x + 50, floorH - 12))
            diag.move(to: P(x + 50, 12)); diag.addLine(to: P(x, floorH - 12))
        }
        stroke(diag, ink, 8); stroke(diag, rust, 5)
        stroke(diag, rust.lighter(0.35).alpha(0.6), 1.4)
        for i in 0...6 {
            let x = CGFloat(i) * 50
            let c = rect(R(x - 6, 8, 12, floorH - 16))
            lfill(c, [rust.lighter(0.3), rust, rust.darker(0.35)], P(x - 6, 0), P(x + 6, 0)); stroke(c, ink, 1.4)
            for y in stride(from: CGFloat(20), to: floorH - 14, by: 14) { rivet(P(x, y), 1.8, Col(hex: 0xA65B35)) }
            // Gusset plates.
            fill(circle(P(x, floorH / 2), 7), rust.darker(0.15)); stroke(circle(P(x, floorH / 2), 7), ink, 1.2)
        }
    }
    beam(R(0, 0, floorW, 12), rust.darker(0.1))
    beam(R(0, floorH - 12, floorW, 12), rust.darker(0.1))
}

canvas("floor_residential", floorW, floorH, residentialFloor)
canvas("floor_office", floorW, floorH, officeFloor)
canvas("floor_garden", floorW, floorH, gardenFloor)
canvas("floor_penthouse", floorW, floorH, penthouseFloor)
canvas("floor_girder", floorW, floorH, girderFloor)

// Foundation: concrete podium with a hi-vis hoarding.
canvas("foundation", 430, 170) {
    vfill(rect(R(0, 40, 430, 130)), [Col(hex: 0x7A6A55), Col(hex: 0x4E4234)])
    var g = Rng(s: 5)
    for _ in 0..<70 { fill(circle(P(g.r(0, 430), g.r(60, 170)), g.r(1, 3)), Col(hex: 0x3A3127, 0.6)) }
    let pad = R(65, 22, 300, 30)
    shadowed(3, 5) { part(rect(pad), concrete, outline: 1.8) }
    for i in 0..<6 { stroke(line(P(65 + CGFloat(i) * 60, 22), P(65 + CGFloat(i) * 60, 52)), ink.alpha(0.35), 1) }
    // Hoarding panels.
    for i in 0..<5 {
        let r = R(CGFloat(i) * 88 - 4, 60, 86, 50)
        part(rect(r), i % 2 == 0 ? Col(hex: 0x2E5A44) : Col(hex: 0x2A5240), outline: 1.6)
    }
    hazard(R(0, 108, 430, 10), width: 9)
    stroke(rect(R(0, 108, 430, 10)), ink, 1.4)
    text("RIVET RISE · SITE 18", P(215, 85), size: 18, color: Col(hex: 0xF4EFE2), kern: 2)
}

// MARK: - Crane parts

canvas("crane_jib", 470, 64) {
    truss(R(0, 14, 470, 34), hiVis, bay: 26, chord: 5, web: 2.6)
    // Counter-jib weights on the left.
    for i in 0..<3 {
        let r = R(6 + CGFloat(i) * 22, 46, 20, 16)
        part(rect(r), concrete, outline: 1.4)
    }
    // Trolley rail.
    fill(rect(R(90, 47, 380, 3)), ink.alpha(0.8))
}

canvas("crane_trolley", 64, 34) {
    let body = rr(R(6, 4, 52, 20), 4)
    shadowed(2, 3) { part(body, hiVis, outline: 1.8) }
    hazard(R(9, 16, 46, 5), width: 4)
    for x in [16.0, 48] { rivet(P(x, 27), 5, graphite) }
}

canvas("crane_hook", 56, 84) {
    // Hook block with sheave.
    let block = rr(R(8, 4, 40, 36), 6)
    shadowed(2, 3) { part(block, hiVis, outline: 2) }
    hazard(R(11, 24, 34, 9), width: 5)
    stroke(rr(R(11, 24, 34, 9), 1), ink, 1)
    rivet(P(28, 14), 6, Col(hex: 0x9AA3AD))
    // Hook.
    let hook = CGMutablePath()
    hook.move(to: P(28, 40)); hook.addLine(to: P(28, 56))
    hook.addArc(center: P(22, 60), radius: 12, startAngle: -.pi / 3, endAngle: .pi * 0.95, clockwise: false)
    stroke(hook, ink, 8); stroke(hook, Col(hex: 0x8C949E), 5); stroke(hook, Col.white.alpha(0.35), 1.4)
}

canvas("spark", 24, 24) {
    rfill(circle(P(12, 12), 12), [Col(1, 1, 0.9, 1), Col(1, 0.8, 0.3, 0.8), Col(1, 0.5, 0.1, 0)], P(12, 12), 12)
}

canvas("dust", 40, 40) {
    rfill(circle(P(20, 20), 20), [Col(0.9, 0.86, 0.8, 0.9), Col(0.8, 0.75, 0.68, 0.4), Col(0.8, 0.75, 0.68, 0)], P(20, 20), 20)
}

// MARK: - Skies (430 x 932): the game backdrop changes with height and shift

func sky(_ name: String, _ stops: [Col], _ locs: [CGFloat], sun: (CGPoint, Col)?, city: Col, lit: Col?, clouds: Col, cloudUnder: Col, stars: Bool = false) {
    canvas(name, 430, 932) {
        vfill(rect(R(0, 0, 430, 932)), stops, locs)
        if stars {
            var g = Rng(s: 77)
            for _ in 0..<140 { fill(circle(P(g.r(0, 430), g.r(0, 640)), g.r(0.4, 1.3)), Col(1, 1, 0.95, g.r(0.3, 0.95))) }
            fill(circle(P(330, 150), 26), Col(hex: 0xF4F0DE))
            fill(circle(P(342, 142), 24), stops[0])
        }
        if let (c, col) = sun {
            glow(c, 220, col.alpha(0.8))
            fill(circle(c, 38), col.lighter(0.5))
        }
        for (i, y) in [150.0, 330, 520].enumerated() {
            cloud(R(i % 2 == 0 ? -40 : 210, y, 260, 90), seed: UInt64(100 + i), top: clouds, under: cloudUnder, alpha: 0.85 - CGFloat(i) * 0.15)
        }
        skyline(900, city.lighter(0.25), lit: nil, seed: 9, maxH: 170, minW: 20, maxW: 44)
        skyline(932, city, lit: lit, seed: 3, maxH: 120)
    }
}

sky("sky_dawn", [Col(hex: 0x3E8EA8), Col(hex: 0x7FBBC0), Col(hex: 0xF6C59A), Col(hex: 0xF29C6B)], [0, 0.4, 0.78, 1],
    sun: (P(110, 760), Col(hex: 0xFFD9A0)), city: Col(hex: 0x5B5A6E), lit: Col(hex: 0xFFD98A, 0.7), clouds: Col(hex: 0xFFF1E4), cloudUnder: Col(hex: 0xE7A98E))
sky("sky_day", [Col(hex: 0x2F86C9), Col(hex: 0x69B4E0), Col(hex: 0xBFE2F0), Col(hex: 0xEDE6D2)], [0, 0.45, 0.82, 1],
    sun: (P(330, 120), Col(hex: 0xFFF6D8)), city: Col(hex: 0x7E93A6), lit: nil, clouds: .white, cloudUnder: Col(hex: 0xC6D8E8))
sky("sky_dusk", [Col(hex: 0x3B2D5C), Col(hex: 0x8C4A6E), Col(hex: 0xE97E57), Col(hex: 0xF7B865)], [0, 0.42, 0.8, 1],
    sun: (P(300, 820), Col(hex: 0xFFB45E)), city: Col(hex: 0x2F2440), lit: Col(hex: 0xFFC46B, 0.85), clouds: Col(hex: 0xF9C3A0), cloudUnder: Col(hex: 0x9C5470))
sky("sky_night", [Col(hex: 0x0B1426), Col(hex: 0x16264A), Col(hex: 0x2A3B66), Col(hex: 0x3D3F5E)], [0, 0.5, 0.85, 1],
    sun: nil, city: Col(hex: 0x10141F), lit: Col(hex: 0xFFD27A, 0.9), clouds: Col(hex: 0x3A4A72), cloudUnder: Col(hex: 0x1F2A48), stars: true)

canvas("fog_bank", 430, 300) {
    for i in 0..<7 {
        cloud(R(CGFloat(i % 3) * 150 - 60, CGFloat(i) * 34, 280, 110), seed: UInt64(300 + i), top: Col(hex: 0xF2F0EA), under: Col(hex: 0xC9CBC9), alpha: 0.85)
    }
}

// MARK: - The building site (home screen backdrop, 430 x 932)

func towerCrane(mastX: CGFloat, top: CGFloat, ground: CGFloat, jibLeft: CGFloat, jibRight: CGFloat) {
    mast(R(mastX - 14, top, 28, ground - top), hiVis)
    // Jib and counter-jib.
    truss(R(jibLeft, top - 6, jibRight - jibLeft, 26), hiVis, bay: 22, chord: 4, web: 2.2)
    // Apex and tie bars.
    let apex = P(mastX, top - 64)
    stroke(poly([P(mastX - 14, top - 6), apex, P(mastX + 14, top - 6)]), ink, 4.5)
    stroke(poly([P(mastX - 14, top - 6), apex, P(mastX + 14, top - 6)]), hiVis, 2.5)
    stroke(line(apex, P(jibRight - 30, top - 6)), ink, 1.6)
    stroke(line(apex, P(jibLeft + 10, top - 6)), ink, 1.6)
    // Counterweights.
    for i in 0..<3 { part(rect(R(jibLeft + 6 + CGFloat(i) * 18, top + 20, 16, 22)), concrete, outline: 1.4) }
    // Cab.
    let cab = rr(R(mastX + 10, top + 22, 40, 34), 5)
    shadowed(2, 3) { part(cab, hiVis, outline: 1.8) }
    vfill(rr(R(mastX + 16, top + 27, 28, 16), 3), [Col(hex: 0xBFE6F2), Col(hex: 0x5EA1C4)])
    stroke(rr(R(mastX + 16, top + 27, 28, 16), 3), ink, 1.2)
    // Warning lamp.
    glow(apex, 18, alarm.alpha(0.8)); fill(circle(apex, 3.5), alarm.lighter(0.3))
}

canvas("bg_site", 430, 932) {
    vfill(rect(R(0, 0, 430, 932)), [Col(hex: 0x3E8EA8), Col(hex: 0x86C1C2), Col(hex: 0xF6C59A), Col(hex: 0xF3A372)], [0, 0.35, 0.68, 0.86])
    glow(P(320, 610), 260, Col(hex: 0xFFE2B0, 0.9))
    fill(circle(P(320, 610), 44), Col(hex: 0xFFEFCF))
    cloud(R(-40, 170, 240, 80), seed: 1, top: Col(hex: 0xFFF2E6), under: Col(hex: 0xE5AE93), alpha: 0.9)
    cloud(R(230, 300, 230, 76), seed: 2, top: Col(hex: 0xFFF2E6), under: Col(hex: 0xE5AE93), alpha: 0.75)
    skyline(770, Col(hex: 0x7C7C8E), lit: nil, seed: 21, maxH: 190, minW: 22, maxW: 48)
    skyline(800, Col(hex: 0x55546A), lit: Col(hex: 0xFFD98A, 0.65), seed: 22, maxH: 130)

    // Unfinished tower: concrete core with a few floors of steel frame.
    let towerX: CGFloat = 250, towerW: CGFloat = 130
    for i in 0..<9 {
        let y = 790 - CGFloat(i + 1) * 40
        let r = R(towerX, y, towerW, 40)
        if i < 6 {
            part(rect(r), i % 2 == 0 ? Col(hex: 0xC9C3B8) : Col(hex: 0xBDB6AA), outline: 1.4, light: 0.15, dark: 0.15)
            for k in 0..<4 { window(R(towerX + 10 + CGFloat(k) * 30, y + 9, 20, 22), glass: Col(hex: 0x7FB3D6), lit: (i + k) % 3 == 0) }
        } else {
            for k in 0...4 { fill(rect(R(towerX + CGFloat(k) * 32.5 - 2, y, 4, 40)), rust) ; stroke(rect(R(towerX + CGFloat(k) * 32.5 - 2, y, 4, 40)), ink, 1) }
            beam(R(towerX - 4, y - 3, towerW + 8, 7), rust.darker(0.1))
        }
    }
    // Scaffold netting on the right side.
    clipped(rect(R(towerX + towerW - 26, 430, 30, 360))) {
        fill(rect(R(towerX + towerW - 26, 430, 30, 360)), safetyGreen.alpha(0.55))
        for y in stride(from: CGFloat(430), to: 790, by: 8) { stroke(line(P(towerX + towerW - 26, y), P(towerX + towerW + 4, y + 4)), Col(hex: 0x1F5A33, 0.6), 0.8) }
    }

    // Tower crane, its hook hanging over the tower.
    towerCrane(mastX: 120, top: 250, ground: 800, jibLeft: 30, jibRight: 420)
    stroke(line(P(322, 268), P(322, 380)), ink, 1.6)
    canvasDrawHook(P(322, 380))

    // Ground, hoarding and site details.
    vfill(rect(R(0, 790, 430, 142)), [Col(hex: 0x8A7558), Col(hex: 0x5C4B39)])
    var g = Rng(s: 8)
    for _ in 0..<120 { fill(circle(P(g.r(0, 430), g.r(796, 932)), g.r(0.8, 2.6)), Col(hex: 0x3F3428, 0.5)) }
    // Stack of girders and a cone.
    for i in 0..<3 { beam(R(20 + CGFloat(i) * 6, 818 - CGFloat(i) * 9, 120, 9), rust.darker(0.05), rivets: false) }
    let cone = poly([P(380, 840), P(392, 800), P(404, 840)])
    part(cone, Col(hex: 0xF07A2A), outline: 1.6)
    fill(rect(R(386, 816, 12, 5)), .white)
    part(rect(R(374, 838, 36, 6)), Col(hex: 0xF07A2A), outline: 1.4)
}

func canvasDrawHook(_ p: CGPoint) {
    let block = rr(R(p.x - 10, p.y, 20, 18), 3)
    part(block, hiVis, outline: 1.6)
    hazard(R(p.x - 8, p.y + 11, 16, 5), width: 3)
    let hook = CGMutablePath()
    hook.move(to: P(p.x, p.y + 18)); hook.addLine(to: P(p.x, p.y + 26))
    hook.addArc(center: P(p.x - 3, p.y + 28), radius: 6, startAngle: -.pi / 3, endAngle: .pi * 0.95, clockwise: false)
    stroke(hook, ink, 4.5); stroke(hook, Col(hex: 0x8C949E), 2.5)
}

// MARK: - Textures and panels

canvas("tex_manila", 120, 120) {
    fill(rect(R(0, 0, 120, 120)), manila)
    var g = Rng(s: 2)
    for _ in 0..<500 { fill(rect(R(g.r(0, 120), g.r(0, 120), g.r(0.5, 2.2), 0.6)), Col(hex: 0xB89E6E, g.r(0.08, 0.25))) }
}

canvas("tex_concrete", 160, 160) {
    fill(rect(R(0, 0, 160, 160)), Col(hex: 0x8D8981))
    var g = Rng(s: 3)
    for _ in 0..<900 { fill(circle(P(g.r(0, 160), g.r(0, 160)), g.r(0.3, 1.4)), g.next() > 0.5 ? Col(hex: 0x6F6B64, 0.5) : Col(hex: 0xA9A59C, 0.5)) }
    for _ in 0..<6 { fill(circle(P(g.r(0, 160), g.r(0, 160)), g.r(1.5, 3)), Col(hex: 0x5D5953, 0.6)) }
}

canvas("tex_pegsteel", 120, 120) {
    vfill(rect(R(0, 0, 120, 120)), [Col(hex: 0x3A3F47), Col(hex: 0x30343B)])
    for y in stride(from: CGFloat(10), to: 120, by: 20) {
        for x in stride(from: CGFloat(10), to: 120, by: 20) {
            fill(circle(P(x, y), 2.4), Col(hex: 0x1D2025)); fill(circle(P(x + 0.6, y + 0.8), 1.2), Col.white.alpha(0.08))
        }
    }
}

/// 9-slice steel beam plate for HUD readouts (caps 12 pt).
canvas("plate_beam", 80, 44) {
    let r = rr(R(1, 1, 78, 42), 5)
    part(r, graphite, outline: 2, light: 0.35, dark: 0.3)
    fill(rect(R(4, 5, 72, 3)), Col.white.alpha(0.18))
    for x in [7.0, 73] { for y in [8.0, 36] { rivet(P(x, y), 2.4) } }
}

/// 9-slice hi-vis panel (caps 14 pt).
canvas("plate_hivis", 80, 50) {
    let r = rr(R(1.5, 1.5, 77, 47), 6)
    part(r, hiVis, outline: 2.2)
    for x in [8.0, 72] { for y in [8.0, 42] { rivet(P(x, y), 2.4, Col(hex: 0xA1A7AE)) } }
}

// MARK: - HUD art

canvas("icon_bolt", 60, 60) {
    // Hex bolt head seen from above, with a washer.
    shadowed(2, 3) { part(circle(P(30, 30), 26), Col(hex: 0xA6AEB8), outline: 2) }
    var pts: [CGPoint] = []
    for i in 0..<6 { let a = CGFloat(i) * .pi / 3 + .pi / 6; pts.append(P(30 + cos(a) * 18, 30 + sin(a) * 18)) }
    let hex = poly(pts)
    part(hex, Col(hex: 0xE3B53A), outline: 2, light: 0.4)
    fill(circle(P(30, 30), 6), Col(hex: 0xB8861E)); stroke(circle(P(30, 30), 6), ink.alpha(0.7), 1.2)
    fill(ellipse(R(17, 14, 16, 8)), Col.white.alpha(0.35))
}

canvas("hard_hat", 60, 48) {
    let dome = CGMutablePath()
    dome.move(to: P(8, 36)); dome.addCurve(to: P(52, 36), control1: P(8, 2), control2: P(52, 2)); dome.closeSubpath()
    shadowed(2, 2) { part(dome, hiVis, outline: 2.2) }
    fill(rr(R(26, 8, 8, 26), 3), hiVis.lighter(0.25)); stroke(rr(R(26, 8, 8, 26), 3), ink.alpha(0.5), 1)
    let brim = rr(R(2, 34, 56, 9), 4.5)
    part(brim, hiVisDeep, outline: 2)
    fill(ellipse(R(14, 12, 12, 7)), Col.white.alpha(0.45))
}

canvas("hard_hat_empty", 60, 48) {
    let dome = CGMutablePath()
    dome.move(to: P(8, 36)); dome.addCurve(to: P(52, 36), control1: P(8, 2), control2: P(52, 2)); dome.closeSubpath()
    fill(dome, Col(0.1, 0.1, 0.12, 0.45)); stroke(dome, Col.white.alpha(0.55), 1.8)
    let brim = rr(R(2, 34, 56, 9), 4.5)
    fill(brim, Col(0.1, 0.1, 0.12, 0.45)); stroke(brim, Col.white.alpha(0.55), 1.8)
    stroke(line(P(22, 14), P(30, 24)), Col.white.alpha(0.5), 1.6); stroke(line(P(30, 24), P(26, 32)), Col.white.alpha(0.5), 1.6)
}

canvas("weathervane", 90, 90) {
    // Arrow pointing right (rotated in the app), cockerel-free construction vane.
    shadowed(2, 3) {
        let shaft = rr(R(10, 41, 66, 8), 3)
        part(shaft, Col(hex: 0x3A3F47), outline: 1.8)
        let head = poly([P(70, 30), P(88, 45), P(70, 60)])
        part(head, alarm, outline: 2)
        let tail = poly([P(4, 30), P(22, 40), P(22, 50), P(4, 60), P(12, 45)])
        part(tail, hiVis, outline: 2)
    }
    rivet(P(45, 45), 5, Col(hex: 0x9AA3AD))
}

canvas("plumb_bob", 50, 80) {
    stroke(line(P(25, 0), P(25, 26)), ink, 2)
    let bob = CGMutablePath()
    bob.move(to: P(25, 76)); bob.addLine(to: P(10, 42)); bob.addCurve(to: P(40, 42), control1: P(12, 22), control2: P(38, 22)); bob.closeSubpath()
    shadowed(2, 3) { part(bob, Col(hex: 0xC99325), outline: 2, light: 0.45) }
    fill(rr(R(18, 22, 14, 8), 2), Col(hex: 0x8C949E)); stroke(rr(R(18, 22, 14, 8), 2), ink, 1.4)
    fill(ellipse(R(15, 36, 6, 12)), Col.white.alpha(0.45))
}

canvas("gauge_rush", 120, 120) {
    let c = P(60, 60)
    shadowed(2, 4) { part(circle(c, 56), Col(hex: 0x9AA3AD), outline: 2.2, light: 0.5) }
    fill(circle(c, 46), Col(hex: 0xF4EFE2)); stroke(circle(c, 46), ink, 1.6)
    // Arc from green to red over 240 degrees.
    let start = CGFloat.pi * 0.75, sweep = CGFloat.pi * 1.5
    for i in 0..<24 {
        let t = CGFloat(i) / 24
        let a0 = start + sweep * t, a1 = start + sweep * (t + 1 / 24)
        let arc = CGMutablePath(); arc.addArc(center: c, radius: 38, startAngle: a0, endAngle: a1, clockwise: false)
        stroke(arc, safetyGreen.mix(hiVis, min(1, t * 2)).mix(alarm, max(0, t * 2 - 1)), 8)
    }
    for i in 0...5 {
        let a = start + sweep * CGFloat(i) / 5
        stroke(line(P(c.x + cos(a) * 30, c.y + sin(a) * 30), P(c.x + cos(a) * 44, c.y + sin(a) * 44)), ink, 2)
    }
    text("RUSH", P(60, 92), size: 12, color: ink, kern: 1.5)
}

canvas("gauge_needle", 120, 120) {
    let c = P(60, 60)
    let needle = poly([P(60, 24), P(64, 62), P(56, 62)])
    shadowed(1, 2) { fill(needle, alarm); stroke(needle, ink, 1.2) }
    rivet(c, 6, Col(hex: 0x6E757E))
}

canvas("tape_measure", 30, 300) {
    let r = R(4, 0, 22, 300)
    vfill(rect(r), [hiVis.lighter(0.15), hiVis])
    stroke(rect(r), ink, 1.4)
    for i in 0..<60 {
        let y = CGFloat(i) * 5
        let long = i % 10 == 0
        stroke(line(P(4, y), P(long ? 18 : (i % 5 == 0 ? 14 : 10), y)), ink, long ? 1.6 : 0.9)
    }
}

// Tenant icons (next module preview and district callouts).
func kindIcon(_ name: String, _ draw: () -> Void) { canvas(name, 64, 64, draw) }
kindIcon("kind_residential") {
    shadowed(2, 3) {
        let house = poly([P(10, 30), P(32, 10), P(54, 30), P(54, 56), P(10, 56)])
        part(house, Col(hex: 0xE09468), outline: 2)
    }
    let roof = poly([P(6, 32), P(32, 8), P(58, 32), P(52, 34), P(32, 16), P(12, 34)])
    part(roof, alarm, outline: 1.8)
    window(R(18, 36, 11, 11), glass: Col(hex: 0x7FB3D6), lit: true)
    fill(rect(R(36, 38, 11, 18)), Col(hex: 0x6B4A2E)); stroke(rect(R(36, 38, 11, 18)), ink, 1.4)
}
kindIcon("kind_office") {
    shadowed(2, 3) { part(rect(R(16, 6, 32, 52)), Col(hex: 0x3F7FA8), outline: 2) }
    for y in stride(from: CGFloat(12), to: 54, by: 8) { for x in [21.0, 30, 39] { fill(rect(R(x, y, 5, 5)), Col(hex: 0xBFE6F2)) } }
    fill(rect(R(10, 56, 44, 4)), graphite)
}
kindIcon("kind_garden") {
    shadowed(2, 3) {
        let crown = CGMutablePath()
        crown.addPath(circle(P(32, 24), 16)); crown.addPath(circle(P(20, 32), 11)); crown.addPath(circle(P(44, 32), 11))
        lfill(crown, [Col(hex: 0x9AD86A), Col(hex: 0x3E9B5A)], P(20, 8), P(44, 44))
    }
    fill(rect(R(29, 38, 6, 12)), Col(hex: 0x6B4A2E))
    part(rr(R(14, 46, 36, 12), 3), Col(hex: 0x8A6A4A), outline: 1.8)
}
kindIcon("kind_penthouse") {
    let crown = poly([P(8, 48), P(10, 18), P(22, 32), P(32, 10), P(42, 32), P(54, 18), P(56, 48)])
    shadowed(2, 3) { part(crown, Col(hex: 0xF0C24A), outline: 2, light: 0.45) }
    for (x, y) in [(10.0, 18.0), (32, 10), (54, 18)] { fill(circle(P(x, y), 4), alarm); stroke(circle(P(x, y), 4), ink, 1.2) }
    part(rect(R(8, 46, 48, 8)), Col(hex: 0xC99325), outline: 1.8)
}

// Site shift badges.
func shiftBadge(_ name: String, _ bg: Col, _ draw: () -> Void) {
    canvas(name, 72, 72) {
        shadowed(2, 3) { part(circle(P(36, 36), 33), bg, outline: 2.2) }
        clipped(circle(P(36, 36), 30)) { draw() }
        stroke(circle(P(36, 36), 30), Col.white.alpha(0.35), 1.2)
    }
}
shiftBadge("shift_clear", Col(hex: 0x7FBBC0)) {
    glow(P(36, 34), 26, Col(hex: 0xFFE2A0)); fill(circle(P(36, 34), 12), Col(hex: 0xFFE7B0)); stroke(circle(P(36, 34), 12), ink, 1.6)
    for i in 0..<8 { let a = CGFloat(i) * .pi / 4; stroke(line(P(36 + cos(a) * 16, 34 + sin(a) * 16), P(36 + cos(a) * 22, 34 + sin(a) * 22)), ink, 2) }
}
shiftBadge("shift_fog", Col(hex: 0x9CA3A8)) {
    for (i, y) in [24.0, 36, 48].enumerated() { stroke(line(P(14 + CGFloat(i % 2) * 6, y), P(58 - CGFloat((i + 1) % 2) * 6, y)), Col(hex: 0xF4F2EC), 5) }
}
shiftBadge("shift_night", Col(hex: 0x1C2B4F)) {
    fill(circle(P(38, 34), 15), Col(hex: 0xF4F0DE)); fill(circle(P(45, 29), 13), Col(hex: 0x1C2B4F))
    for (x, y) in [(18.0, 20.0), (22, 46), (54, 50)] { fill(circle(P(x, y), 1.6), .white) }
}
shiftBadge("shift_jitter", Col(hex: 0xF07A2A)) {
    let z = CGMutablePath(); z.move(to: P(12, 40)); z.addLines(between: [P(12, 40), P(22, 26), P(30, 44), P(40, 24), P(48, 44), P(60, 30)])
    stroke(z, ink, 6); stroke(z, hiVis, 3)
}
shiftBadge("shift_heavy", rust) {
    beam(R(10, 22, 52, 10), graphite, rivets: false)
    beam(R(10, 40, 52, 10), graphite, rivets: false)
    stroke(line(P(20, 32), P(52, 40)), ink, 3)
}
shiftBadge("shift_calm", Col(hex: 0x5FA88A)) {
    stroke(line(P(36, 14), P(36, 58)), ink, 3)
    let flag = poly([P(36, 16), P(37, 16), P(40, 40), P(36, 40)])
    fill(flag, alarm)
    stroke(line(P(18, 58), P(54, 58)), ink, 3)
}

// MARK: - Foremen portraits (240 x 240)

struct ForemanLook {
    let name: String, skin: Col, hair: Col, hat: Col, vest: Col, shirt: Col
    let beard: Bool, longHair: Bool, glasses: Bool, bandana: Bool, smile: CGFloat
}

func drawForeman(_ f: ForemanLook) {
    let bg = rr(R(6, 6, 228, 228), 26)
    clipped(bg) {
        vfill(bg, [skyPeach.mix(skyTeal, 0.2), skyTeal.lighter(0.2)])
        mast(R(170, -10, 30, 260), hiVis.alpha(0.55), bay: 30)
        fill(rect(R(0, 200, 240, 40)), concrete)
    }
    // Shoulders and vest.
    let torso = CGMutablePath()
    torso.move(to: P(36, 240)); torso.addCurve(to: P(204, 240), control1: P(40, 160), control2: P(200, 160)); torso.closeSubpath()
    part(torso, f.shirt, outline: 2.4)
    let vestL = poly([P(56, 240), P(70, 178), P(104, 170), P(100, 240)])
    let vestR = poly([P(184, 240), P(170, 178), P(136, 170), P(140, 240)])
    for v in [vestL, vestR] { part(v, f.vest, outline: 2) }
    for y in [204.0, 222] {
        fill(rect(R(60, y, 40, 6)), Col(hex: 0xDDE3E8)); fill(rect(R(140, y, 40, 6)), Col(hex: 0xDDE3E8))
    }
    // Neck and head.
    part(rect(R(104, 148, 32, 30)), f.skin.darker(0.12), outline: 2)
    if f.longHair {
        let hairBack = rr(R(70, 70, 100, 110), 40)
        part(hairBack, f.hair, outline: 2.2)
    }
    let head = ellipse(R(76, 62, 88, 100))
    shadowed(2, 4) { part(head, f.skin, outline: 2.4, light: 0.2, dark: 0.12) }
    // Ears.
    for x in [72.0, 156] { part(ellipse(R(x, 104, 14, 22)), f.skin.darker(0.05), outline: 2) }
    // Eyes and brows.
    for x in [102.0, 138] {
        fill(ellipse(R(x - 6, 104, 12, 13)), .white); stroke(ellipse(R(x - 6, 104, 12, 13)), ink, 1.4)
        fill(circle(P(x + 1, 111), 3.6), ink); fill(circle(P(x + 2, 109.5), 1.2), .white)
        stroke(line(P(x - 9, 96), P(x + 8, 94)), f.hair.darker(0.2), 3.4)
    }
    if f.glasses {
        for x in [102.0, 138] { stroke(rr(R(x - 12, 100, 24, 20), 5), ink, 2.2) }
        stroke(line(P(114, 108), P(126, 108)), ink, 2)
    }
    // Nose and mouth.
    stroke(line(P(120, 112), P(116, 128)), f.skin.darker(0.35), 2)
    stroke(line(P(116, 128), P(122, 129)), f.skin.darker(0.35), 2)
    if f.beard {
        let beard = CGMutablePath()
        beard.move(to: P(80, 118)); beard.addCurve(to: P(160, 118), control1: P(84, 178), control2: P(156, 178))
        beard.addCurve(to: P(80, 118), control1: P(150, 140), control2: P(90, 140))
        part(beard, f.hair, outline: 2)
    }
    let mouth = CGMutablePath()
    mouth.move(to: P(108, 140)); mouth.addQuadCurve(to: P(132, 140), control: P(120, 140 + f.smile))
    stroke(mouth, ink, 2.6)
    // Cheeks.
    fill(ellipse(R(88, 124, 14, 8)), alarm.alpha(0.18)); fill(ellipse(R(138, 124, 14, 8)), alarm.alpha(0.18))
    // Hard hat.
    if f.bandana {
        let band = rr(R(76, 84, 88, 12), 4)
        part(band, alarm, outline: 1.8)
    }
    let dome = CGMutablePath()
    dome.move(to: P(72, 92)); dome.addCurve(to: P(168, 92), control1: P(70, 30), control2: P(170, 30)); dome.closeSubpath()
    shadowed(2, 3) { part(dome, f.hat, outline: 2.4) }
    part(rr(R(112, 46, 16, 44), 5), f.hat.lighter(0.2), outline: 1.6)
    part(rr(R(62, 86, 116, 13), 6), f.hat.darker(0.15), outline: 2.2)
    fill(ellipse(R(90, 54, 20, 10)), Col.white.alpha(0.4))
}

let foremen: [ForemanLook] = [
    ForemanLook(name: "gus", skin: Col(hex: 0xE8B48E), hair: Col(hex: 0xC9C5BE), hat: hiVis, vest: Col(hex: 0xF07A2A), shirt: Col(hex: 0x4C6B86), beard: true, longHair: false, glasses: false, bandana: false, smile: 6),
    ForemanLook(name: "mira", skin: Col(hex: 0xC98E66), hair: Col(hex: 0x2C1E18), hat: Col(hex: 0xF4F2EC), vest: hiVis, shirt: Col(hex: 0x6E3B5E), beard: false, longHair: true, glasses: false, bandana: false, smile: 8),
    ForemanLook(name: "dolores", skin: Col(hex: 0xF0C8A6), hair: Col(hex: 0x8A3A26), hat: Col(hex: 0x3F7FA8), vest: hiVis, shirt: Col(hex: 0x3E9B5A), beard: false, longHair: true, glasses: true, bandana: false, smile: 4),
    ForemanLook(name: "kenji", skin: Col(hex: 0xE6BE96), hair: Col(hex: 0x1E1A18), hat: safetyGreen, vest: Col(hex: 0xF07A2A), shirt: Col(hex: 0xD9CBA8), beard: false, longHair: false, glasses: true, bandana: false, smile: 7),
    ForemanLook(name: "tony", skin: Col(hex: 0x8E5B3E), hair: Col(hex: 0x1E1A18), hat: alarm, vest: hiVis, shirt: Col(hex: 0x343841), beard: true, longHair: false, glasses: false, bandana: true, smile: 9),
    ForemanLook(name: "ola", skin: Col(hex: 0xF3D2B8), hair: Col(hex: 0xE8C25A), hat: Col(hex: 0xF07A2A), vest: hiVis, shirt: Col(hex: 0x2F86C9), beard: false, longHair: true, glasses: false, bandana: true, smile: 10)
]
for f in foremen { canvas("foreman_\(f.name)", 240, 240) { drawForeman(f) } }

// MARK: - Upgrade loads (hanging from a hook, 200 x 220)

func load(_ name: String, _ draw: () -> Void) {
    canvas(name, 200, 220) {
        // Sling from the top centre.
        stroke(line(P(100, 0), P(100, 26)), ink, 3)
        canvasDrawHookSmall(P(100, 22))
        draw()
    }
}

func canvasDrawHookSmall(_ p: CGPoint) {
    let hook = CGMutablePath()
    hook.move(to: P(p.x, p.y)); hook.addLine(to: P(p.x, p.y + 10))
    hook.addArc(center: P(p.x - 4, p.y + 14), radius: 7, startAngle: -.pi / 3, endAngle: .pi * 0.95, clockwise: false)
    stroke(hook, ink, 5.5); stroke(hook, Col(hex: 0x8C949E), 3)
}

func slings(to a: CGPoint, _ b: CGPoint) {
    stroke(line(P(98, 42), a), ink, 2.4); stroke(line(P(98, 42), b), ink, 2.4)
}

load("upgrade_cable") {
    slings(to: P(56, 96), P(144, 96))
    // Cable drum.
    let drum = rr(R(40, 90, 120, 100), 14)
    shadowed(3, 5) { part(drum, Col(hex: 0x8C6A42), outline: 2.4) }
    for i in 0..<9 {
        let y = 102 + CGFloat(i) * 9.5
        stroke(line(P(48, y), P(152, y + 4)), ink.alpha(0.7), 4.2)
        stroke(line(P(48, y), P(152, y + 4)), Col(hex: 0xB9C1CA), 2.6)
    }
    for x in [36.0, 154] { part(rr(R(x, 84, 10, 112), 4), Col(hex: 0x6B4A2E), outline: 2) }
}

load("upgrade_counterweight") {
    slings(to: P(50, 92), P(150, 92))
    for i in 0..<3 {
        let r = R(42, 88 + CGFloat(i) * 38, 116, 34)
        shadowed(2, 4) { part(rect(r), concrete, outline: 2.2) }
        text("5T", P(100, r.midY), size: 18, color: ink.alpha(0.65))
    }
    part(rect(R(36, 84, 128, 8)), graphite, outline: 1.8)
}

load("upgrade_concrete") {
    slings(to: P(62, 80), P(138, 80))
    // Concrete bucket (skip).
    let bucket = poly([P(52, 80), P(148, 80), P(128, 170), P(72, 170)])
    shadowed(3, 5) { part(bucket, Col(hex: 0x8C949E), outline: 2.4) }
    hazard(R(58, 94, 84, 10), width: 8)
    stroke(rect(R(58, 94, 84, 10)), ink, 1.4)
    let pour = CGMutablePath()
    pour.move(to: P(92, 170)); pour.addCurve(to: P(100, 214), control1: P(88, 190), control2: P(104, 200))
    pour.addLine(to: P(110, 214)); pour.addCurve(to: P(108, 170), control1: P(112, 200), control2: P(104, 186)); pour.closeSubpath()
    part(pour, concreteLight, outline: 1.8)
    fill(ellipse(R(58, 74, 84, 14)), concrete.darker(0.1)); stroke(ellipse(R(58, 74, 84, 14)), ink, 2)
}

load("upgrade_boom") {
    slings(to: P(20, 110), P(180, 110))
    ctx.saveGState(); ctx.translateBy(x: 100, y: 130); ctx.rotate(by: -0.12); ctx.translateBy(x: -100, y: -130)
    truss(R(10, 110, 180, 36), hiVis, bay: 24, chord: 5, web: 2.6)
    ctx.restoreGState()
    text("+ REACH", P(100, 182), size: 18, color: ink)
}

load("upgrade_rivetGun") {
    slings(to: P(70, 84), P(140, 84))
    shadowed(3, 5) {
        let body = rr(R(46, 84, 110, 46), 12)
        part(body, alarm, outline: 2.4)
        let grip = poly([P(78, 126), P(108, 126), P(98, 186), P(70, 186)])
        part(grip, graphite, outline: 2.2)
        let nozzle = rr(R(150, 96, 34, 22), 5)
        part(nozzle, Col(hex: 0x8C949E), outline: 2)
    }
    for x in [62.0, 82, 102] { rivet(P(x, 98), 3.4) }
    glow(P(188, 107), 18, Col(hex: 0xFFC860))
    fill(rect(R(70, 112, 70, 6)), hiVis)
}

// MARK: - Site art: hoist pendant pictograms, time clock, punch card, lockers, envelope

func pictogram(_ name: String, _ draw: () -> Void) { canvas(name, 64, 64, draw) }
pictogram("pict_yard") { canvasDrawHookSmall(P(34, 6)); part(rect(R(16, 36, 32, 22)), concrete, outline: 2); stroke(line(P(30, 30), P(18, 36)), ink, 2); stroke(line(P(30, 30), P(46, 36)), ink, 2) }
pictogram("pict_lockers") {
    for i in 0..<3 { let r = R(8 + CGFloat(i) * 17, 8, 15, 50); part(rect(r), steel, outline: 1.8); for k in 0..<3 { stroke(line(P(r.minX + 3, 14 + CGFloat(k) * 4), P(r.maxX - 3, 14 + CGFloat(k) * 4)), ink.alpha(0.6), 1.2) }; fill(rect(R(r.maxX - 5, 32, 2, 8)), ink) }
}
pictogram("pict_log") {
    part(rr(R(12, 8, 40, 52), 4), Col(hex: 0x8C6A42), outline: 2)
    part(rect(R(16, 14, 32, 42)), manila, outline: 1.4, light: 0.1, dark: 0.05)
    for k in 0..<5 { stroke(line(P(20, 22 + CGFloat(k) * 7), P(44, 22 + CGFloat(k) * 7)), ink.alpha(0.6), 1.4) }
    part(rr(R(24, 4, 16, 8), 2), Col(hex: 0x9AA3AD), outline: 1.6)
}
pictogram("pict_manual") {
    part(rr(R(10, 10, 44, 46), 4), alarm, outline: 2)
    fill(rect(R(14, 14, 36, 38)), manila)
    text("?", P(32, 33), size: 30, color: ink)
}
pictogram("pict_office") {
    let gear = CGMutablePath()
    for i in 0..<16 { let a = CGFloat(i) * .pi / 8; let rad: CGFloat = i % 2 == 0 ? 26 : 20; if i == 0 { gear.move(to: P(32 + cos(a) * rad, 32 + sin(a) * rad)) } else { gear.addLine(to: P(32 + cos(a) * rad, 32 + sin(a) * rad)) } }
    gear.closeSubpath()
    part(gear, Col(hex: 0x9AA3AD), outline: 2)
    fill(circle(P(32, 32), 8), graphite); stroke(circle(P(32, 32), 8), ink, 1.6)
}

pictogram("pict_board") {
    // Podium of three steel blocks with a hard hat on the winner's step.
    part(rect(R(6, 36, 18, 22)), Col(hex: 0xC9CED4), outline: 1.8)
    part(rect(R(23, 24, 18, 34)), Col(hex: 0xF0C24A), outline: 1.8)
    part(rect(R(40, 42, 18, 16)), Col(hex: 0xD9925A), outline: 1.8)
    text("1", P(32, 41), size: 14, color: ink)
    let dome = CGMutablePath()
    dome.move(to: P(22, 21)); dome.addCurve(to: P(42, 21), control1: P(22, 6), control2: P(42, 6)); dome.closeSubpath()
    part(dome, hiVis, outline: 1.8)
    part(rr(R(19, 20, 26, 4), 2), hiVisDeep, outline: 1.4)
}

canvas("time_clock", 150, 190) {
    let body = rr(R(10, 10, 130, 170), 14)
    shadowed(4, 6) { part(body, Col(hex: 0x7C8B97), outline: 2.6) }
    // Clock face.
    let c = P(75, 64)
    part(circle(c, 40), Col(hex: 0xF4EFE2), outline: 2.4, light: 0.1, dark: 0.08)
    for i in 0..<12 { let a = CGFloat(i) * .pi / 6; stroke(line(P(c.x + cos(a) * 31, c.y + sin(a) * 31), P(c.x + cos(a) * 36, c.y + sin(a) * 36)), ink, i % 3 == 0 ? 2.6 : 1.4) }
    stroke(line(c, P(c.x + 2, c.y - 24)), ink, 3)
    stroke(line(c, P(c.x + 20, c.y + 8)), ink, 2.2)
    stroke(line(c, P(c.x - 10, c.y + 26)), alarm, 1.4)
    fill(circle(c, 3.4), ink)
    // Card slot.
    let slot = rr(R(32, 122, 86, 16), 4)
    fill(slot, ink); stroke(slot, Col.white.alpha(0.25), 1)
    text("CLOCK IN", P(75, 158), size: 16, color: Col(hex: 0xF4EFE2), kern: 1.5)
}

canvas("punch_card", 120, 64) {
    let card = rr(R(2, 2, 116, 60), 4)
    shadowed(2, 3) { part(card, Col(hex: 0xF4EAC8), outline: 1.6, light: 0.1, dark: 0.06) }
    fill(rect(R(2, 2, 116, 12)), Col(hex: 0xE86A4A))
    for k in 0..<4 { stroke(line(P(10, 24 + CGFloat(k) * 9), P(110, 24 + CGFloat(k) * 9)), Col(hex: 0x9A8A60, 0.6), 1) }
    for i in 0..<6 { fill(rect(R(14 + CGFloat(i) * 16, 22 + CGFloat(i % 3) * 9, 6, 4)), ink.alpha(0.8)) }
}

canvas("locker_closed", 120, 260) {
    let body = rect(R(4, 4, 112, 252))
    part(body, steel, outline: 2.4, light: 0.25, dark: 0.25)
    for k in 0..<6 { stroke(line(P(26, 22 + CGFloat(k) * 8), P(94, 22 + CGFloat(k) * 8)), ink.alpha(0.55), 3) }
    for k in 0..<6 { stroke(line(P(26, 210 + CGFloat(k) * 6), P(94, 210 + CGFloat(k) * 6)), ink.alpha(0.45), 2.4) }
    part(rr(R(92, 110, 10, 40), 3), Col(hex: 0x9AA3AD), outline: 1.6)
    part(rr(R(30, 74, 60, 24), 3), Col(hex: 0xF4EAC8), outline: 1.4, light: 0.05, dark: 0.05)
}

canvas("locker_open", 120, 260) {
    let body = rect(R(4, 4, 112, 252))
    part(body, Col(hex: 0x2B323A), outline: 2.4, light: 0.1, dark: 0.2)
    fill(rect(R(8, 70, 104, 4)), Col(hex: 0x8C949E))
    stroke(line(P(60, 74), P(60, 84)), Col(hex: 0x8C949E), 2)
    // Hanging hi-vis vest.
    let vest = poly([P(36, 88), P(52, 84), P(60, 96), P(68, 84), P(84, 88), P(88, 170), P(32, 170)])
    part(vest, hiVis, outline: 2)
    fill(rect(R(34, 130, 52, 6)), Col(hex: 0xDDE3E8)); fill(rect(R(34, 148, 52, 6)), Col(hex: 0xDDE3E8))
    // Boots.
    for x in [24.0, 64] { part(rr(R(x, 214, 34, 34), 8), Col(hex: 0x6B4A2E), outline: 2) }
    // Door edge (swung open to the left).
    part(poly([P(0, 2), P(10, 10), P(10, 250), P(0, 258)]), steel.darker(0.2), outline: 1.6)
}

canvas("envelope", 340, 420) {
    let body = rr(R(6, 6, 328, 408), 8)
    shadowed(4, 8) { part(body, kraft, outline: 2.4, light: 0.15, dark: 0.15) }
    var g = Rng(s: 12)
    clipped(body) { for _ in 0..<700 { fill(rect(R(g.r(0, 340), g.r(0, 420), g.r(0.5, 3), 0.7)), Col(hex: 0x8C6A3E, g.r(0.08, 0.25))) } }
    // Flap.
    let flap = poly([P(6, 6), P(334, 6), P(170, 92)])
    part(flap, kraft.darker(0.08), outline: 2, light: 0.1, dark: 0.1)
    // Wax-free metal clasp.
    part(circle(P(170, 88), 10), Col(hex: 0xC99325), outline: 1.8, light: 0.5)
    stroke(rect(R(28, 110, 284, 1)), ink.alpha(0.35), 1)
}

canvas("photo_topping", 200, 150) {
    let frame = R(0, 0, 200, 150)
    fill(rect(frame), Col(hex: 0xF7F4EC))
    let pic = R(10, 10, 180, 108)
    clipped(rect(pic)) {
        vfill(rect(pic), [Col(hex: 0x7FBBC0), Col(hex: 0xF6C59A)])
        fill(circle(P(150, 90), 20), Col(hex: 0xFFE7B0, 0.9))
        for i in 0..<8 {
            let r = R(70, 118 - CGFloat(i + 1) * 11, 50, 11)
            part(rect(r), [Col(hex: 0xE09468), Col(hex: 0x3F7FA8), Col(hex: 0x5FA88A)][i % 3], outline: 1, light: 0.1, dark: 0.1)
        }
        // Crowning flag and tree (topping-out tradition).
        stroke(line(P(95, 30), P(95, 10)), ink, 1.6)
        fill(poly([P(95, 10), P(110, 14), P(95, 18)]), alarm)
        fill(circle(P(84, 26), 5), safetyGreen)
    }
    stroke(rect(pic), ink.alpha(0.4), 1)
    text("TOPPED OUT", P(100, 134), size: 13, font: "AmericanTypewriter-Bold", color: ink.alpha(0.8))
}

// MARK: - Hard hat stickers (achievements, 96 x 96)

func sticker(_ name: String, _ bg: Col, _ draw: () -> Void) {
    canvas(name, 96, 96) {
        let s = circle(P(48, 48), 42)
        shadowed(2, 3) { fill(circle(P(48, 48), 45), .white) }
        part(s, bg, outline: 2, light: 0.3)
        clipped(s) { draw() }
    }
}
sticker("sticker_0", hiVis) { part(rect(R(26, 30, 44, 40)), graphite, outline: 2); for i in 0..<3 { stroke(line(P(30, 40 + CGFloat(i) * 9), P(66, 40 + CGFloat(i) * 9)), hiVis, 2) } }
sticker("sticker_1", Col(hex: 0x3F7FA8)) { for i in 0..<5 { part(rect(R(34, 70 - CGFloat(i + 1) * 10, 28, 10)), concreteLight, outline: 1.4) } }
sticker("sticker_2", safetyGreen) { canvasDrawHookSmall(P(50, 14)); part(rect(R(30, 46, 40, 24)), hiVis, outline: 2) }
sticker("sticker_3", alarm) { rivet(P(48, 48), 18, Col(hex: 0xC9CED4)); glow(P(48, 48), 30, Col(hex: 0xFFC860, 0.6)) }
sticker("sticker_4", Col(hex: 0x6E3B5E)) {
    let crown = poly([P(24, 64), P(26, 34), P(38, 48), P(48, 26), P(58, 48), P(70, 34), P(72, 64)])
    part(crown, Col(hex: 0xF0C24A), outline: 2)
}
sticker("sticker_5", Col(hex: 0xF07A2A)) {
    let bolt = poly([P(52, 18), P(30, 52), P(46, 52), P(40, 78), P(66, 40), P(50, 40)])
    part(bolt, hiVis, outline: 2)
}
canvas("sticker_locked", 96, 96) {
    fill(circle(P(48, 48), 42), Col(0.1, 0.1, 0.12, 0.25))
    let dash = circle(P(48, 48), 41)
    ctx.saveGState(); ctx.setLineDash(phase: 0, lengths: [5, 4]); stroke(dash, Col(hex: 0x5A5348), 2); ctx.restoreGState()
    text("?", P(48, 48), size: 34, color: Col(hex: 0x5A5348))
}

canvas("hard_hat_big", 300, 200) {
    let dome = CGMutablePath()
    dome.move(to: P(30, 156)); dome.addCurve(to: P(270, 156), control1: P(26, 6), control2: P(274, 6)); dome.closeSubpath()
    shadowed(4, 8) { part(dome, hiVis, outline: 3) }
    part(rr(R(132, 20, 36, 132), 12), hiVis.lighter(0.2), outline: 2)
    part(rr(R(6, 150, 288, 30), 15), hiVisDeep, outline: 3)
    fill(ellipse(R(70, 46, 60, 26)), Col.white.alpha(0.4))
}

// MARK: - Logo wordmark (360 x 120)

canvas("logo", 360, 120) {
    // Steel I-beam bar with stencilled lettering.
    let bar = rr(R(8, 24, 344, 72), 6)
    shadowed(4, 6) { part(bar, hiVis, outline: 3) }
    hazard(R(11, 27, 338, 10), width: 10)
    hazard(R(11, 83, 338, 10), width: 10)
    fill(rect(R(11, 37, 338, 46)), hiVis)
    stroke(rr(R(8, 24, 344, 72), 6), ink, 3)
    for x in [22.0, 338] { for y in [60.0] { rivet(P(x, y), 4.5) } }
    text("RIVET RISE", P(180, 60), size: 46, color: ink, kern: 3)
    // Hook hanging from the bar.
    stroke(line(P(300, 96), P(300, 106)), ink, 2)
    canvasDrawHookSmall(P(300, 100))
}

// MARK: - Manual illustrations (300 x 190)

func manual(_ name: String, sky: [Col] = [Col(hex: 0x7FBBC0), Col(hex: 0xF6C59A)], _ draw: () -> Void) {
    canvas(name, 300, 190) {
        let frame = rr(R(2, 2, 296, 186), 14)
        clipped(frame) {
            vfill(frame, sky)
            draw()
        }
        stroke(frame, ink, 2.4)
    }
}

func miniFloor(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ kind: Int, h: CGFloat = 18) {
    let cols = [Col(hex: 0xE09468), Col(hex: 0x3F7FA8), Col(hex: 0x5FA88A), Col(hex: 0xF0D9A0), rust]
    let r = R(x - w / 2, y, w, h)
    part(rect(r), cols[kind % cols.count], outline: 1.6, light: 0.2, dark: 0.2)
    fill(rect(R(r.minX, r.minY, r.width, 3)), graphite)
    var wx = r.minX + 6
    while wx < r.maxX - 8 { fill(rect(R(wx, y + 6, 6, 7)), Col(hex: 0xFFE7A3, 0.8)); wx += 12 }
}

func miniTower(_ cx: CGFloat, _ baseY: CGFloat, floors: Int, width: CGFloat = 90, lean: CGFloat = 0) {
    part(rect(R(cx - 70, baseY, 140, 20)), Col(hex: 0x8A7558), outline: 0)
    for i in 0..<floors { miniFloor(cx + lean * CGFloat(i * i) / 10, baseY - CGFloat(i + 1) * 18, width, i) }
}

func miniHook(_ x: CGFloat, _ y: CGFloat) {
    truss(R(0, 6, 300, 16), hiVis, bay: 18, chord: 3, web: 1.8)
    stroke(line(P(x, 22), P(x, y)), ink, 1.6)
    canvasDrawHookSmall(P(x, y - 4))
}

manual("manual_drop") {
    miniTower(150, 168, floors: 4)
    miniHook(190, 64)
    miniFloor(190, 72, 90, 4 % 3)
    // Trim marker.
    ctx.saveGState(); ctx.setLineDash(phase: 0, lengths: [4, 3])
    stroke(line(P(195, 60), P(195, 98)), alarm, 2)
    ctx.restoreGState()
    fill(rect(R(195, 72, 40, 18)), alarm.alpha(0.35))
    stroke(line(P(205, 50), P(225, 50)), ink, 2); fill(poly([P(225, 45), P(233, 50), P(225, 55)]), ink)
    text("TAP", P(56, 60), size: 26, color: ink)
}

manual("manual_sway") {
    for (i, lean) in [-6.0, 0, 6].enumerated() {
        let cx = 70 + CGFloat(i) * 80
        miniTower(cx, 168, floors: 6, width: 54, lean: CGFloat(lean))
        _ = i
    }
    stroke(line(P(150, 30), P(150, 160)), safetyGreen, 3)
    text("IN TUNE", P(150, 22), size: 16, color: safetyGreen.darker(0.3))
    // Plumb bob gauge.
    stroke(line(P(260, 34), P(274, 74)), ink, 1.6)
    part(circle(P(276, 80), 8), Col(hex: 0xC99325), outline: 1.6)
}

manual("manual_rivet") {
    miniTower(150, 168, floors: 3, width: 120)
    let joint = P(150, 114)
    stroke(circle(joint, 34), hiVis, 4)
    stroke(circle(joint, 34), ink, 1)
    stroke(circle(joint, 14), alarm.alpha(0.6), 3)
    rivet(joint, 7)
    glow(joint, 30, Col(hex: 0xFFC860, 0.7))
    text("TAP AGAIN", P(150, 40), size: 22, color: ink)
}

manual("manual_districts") {
    part(rect(R(80, 168, 140, 20)), Col(hex: 0x8A7558), outline: 0)
    for i in 0..<3 { miniFloor(150, 150 - CGFloat(i) * 18, 100, 1) }
    for i in 0..<2 { miniFloor(150, 96 - CGFloat(i) * 18, 100, 2) }
    stroke(rr(R(94, 110, 112, 60), 6), hiVis, 3)
    text("OFFICE x3", P(250, 140), size: 16, color: ink)
    text("+12", P(250, 160), size: 16, color: safetyGreen.darker(0.3))
    for (i, k) in [0, 1, 2].enumerated() { miniFloor(40, 40 + CGFloat(i) * 26, 50, k) }
}

manual("manual_wind", sky: [Col(hex: 0x5C6E8A), Col(hex: 0xC9B8A6)]) {
    miniTower(120, 168, floors: 4)
    miniHook(210, 70)
    miniFloor(210, 78, 70, 0)
    for i in 0..<4 {
        let y = 50 + CGFloat(i) * 22
        let w = CGMutablePath(); w.move(to: P(20, y)); w.addCurve(to: P(110, y), control1: P(50, y - 10), control2: P(80, y + 10))
        stroke(w, Col.white.alpha(0.8), 3)
    }
    // Rush gauge mini.
    part(circle(P(256, 140), 26), Col(hex: 0xF4EFE2), outline: 2)
    stroke(line(P(256, 140), P(272, 124)), alarm, 3)
    text("RUSH", P(256, 176), size: 12, color: ink)
}

manual("manual_shifts", sky: [Col(hex: 0x16264A), Col(hex: 0x8C4A6E)]) {
    var g = Rng(s: 4)
    for _ in 0..<30 { fill(circle(P(g.r(0, 300), g.r(0, 90)), g.r(0.5, 1.4)), .white) }
    miniTower(110, 168, floors: 5)
    miniHook(200, 60)
    // Snapping cable.
    stroke(line(P(200, 22), P(200, 40)), ink, 1.6)
    stroke(line(P(196, 44), P(206, 50)), alarm, 3)
    miniFloor(200, 90, 70, 1)
    text("CREAK!", P(244, 54), size: 18, color: hiVis)
    for (i, n) in ["F", "N", "J"].enumerated() {
        part(circle(P(40 + CGFloat(i) * 30, 30), 12), [Col(hex: 0x9CA3A8), Col(hex: 0x1C2B4F), Col(hex: 0xF07A2A)][i], outline: 1.6)
        text(n, P(40 + CGFloat(i) * 30, 30), size: 12, color: .white)
    }
}

manual("manual_pay", sky: [Col(hex: 0xEADBB8), Col(hex: 0xD9C49A)]) {
    shadowed(3, 5) { part(rr(R(40, 40, 140, 110), 6), kraft, outline: 2) }
    part(poly([P(40, 40), P(180, 40), P(110, 82)]), kraft.darker(0.08), outline: 1.8)
    text("PAY", P(110, 120), size: 26, font: "AmericanTypewriter-Bold", color: ink)
    for i in 0..<4 {
        let c = P(220 + CGFloat(i % 2) * 34, 70 + CGFloat(i / 2) * 40)
        part(circle(c, 15), Col(hex: 0xE3B53A), outline: 1.8)
        fill(circle(c, 4), Col(hex: 0xB8861E))
    }
}

print("done")
