// Rivet Rise sound generator.
// Synthesises every sound effect and the building-site ambience loop as 16-bit mono WAV files.
// Deterministic: noise uses a fixed seed. Usage: swift generate_sounds.swift "<output dir>"

import Foundation

let rate = 44_100.0
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Sounds")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

var noiseState: UInt64 = 0x1234_5678
func noise() -> Double {
    noiseState ^= noiseState << 13; noiseState ^= noiseState >> 7; noiseState ^= noiseState << 17
    return Double(noiseState % 20_000) / 10_000 - 1
}

struct Buffer {
    var s: [Double]
    init(_ seconds: Double) { s = Array(repeating: 0, count: Int(seconds * rate)) }
    var count: Int { s.count }
    mutating func add(_ other: Buffer, at t: Double, gain: Double = 1) {
        let o = Int(t * rate)
        for i in 0..<other.count where o + i < count && o + i >= 0 { s[o + i] += other.s[i] * gain }
    }
}

enum Wave { case sine, square, saw, triangle, noise }
func osc(_ w: Wave, _ phase: Double) -> Double {
    let p = phase - floor(phase)
    switch w {
    case .sine: return sin(p * 2 * .pi)
    case .square: return p < 0.5 ? 1 : -1
    case .saw: return 2 * p - 1
    case .triangle: return 4 * abs(p - 0.5) - 1
    case .noise: return noise()
    }
}

/// A tone whose frequency glides from f0 to f1, shaped by an attack/decay envelope.
func tone(_ w: Wave, _ f0: Double, _ f1: Double, _ dur: Double, attack: Double = 0.005, decay: Double? = nil, vibrato: Double = 0, vibRate: Double = 6, curve: Double = 1) -> Buffer {
    var b = Buffer(dur)
    var phase = 0.0
    for i in 0..<b.count {
        let t = Double(i) / rate
        let k = pow(t / dur, curve)
        let f = f0 + (f1 - f0) * k + vibrato * sin(2 * .pi * vibRate * t)
        phase += f / rate
        let env: Double
        if t < attack { env = t / attack } else {
            let d = decay ?? (dur - attack)
            env = max(0, 1 - (t - attack) / d)
        }
        b.s[i] = osc(w, phase) * env * env
    }
    return b
}
func noiseBurst(_ dur: Double, attack: Double = 0.003, lowpass: Double = 1, highpass: Double = 0, curve: Double = 2) -> Buffer {
    var b = Buffer(dur)
    var lp = 0.0, hpPrev = 0.0, hpOut = 0.0
    for i in 0..<b.count {
        let t = Double(i) / rate
        let env = t < attack ? t / attack : pow(max(0, 1 - (t - attack) / (dur - attack)), curve)
        let n = noise()
        lp += (n - lp) * lowpass
        hpOut = highpass > 0 ? highpass * (hpOut + lp - hpPrev) : lp
        hpPrev = lp
        b.s[i] = hpOut * env
    }
    return b
}
func lowpass(_ b: inout Buffer, _ a: Double) { var y = 0.0; for i in 0..<b.count { y += (b.s[i] - y) * a; b.s[i] = y } }

func write(_ name: String, _ b: Buffer, gain: Double = 0.8) {
    let peak = max(0.0001, b.s.map { abs($0) }.max() ?? 1)
    let scale = gain / peak
    var data = Data()
    func u32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
    func u16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }
    let bytes = UInt32(b.count * 2)
    data.append("RIFF".data(using: .ascii)!); u32(36 + bytes); data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
    data.append("data".data(using: .ascii)!); u32(bytes)
    for v in b.s { var x = Int16(max(-1, min(1, v * scale)) * 32_000).littleEndian; data.append(Data(bytes: &x, count: 2)) }
    try! data.write(to: outDir.appendingPathComponent("\(name).wav"))
}


/// A metallic "ting": a few inharmonic partials that ring out.
func clink(_ base: Double, _ dur: Double) -> Buffer {
    var b = Buffer(dur)
    for (ratio, gain) in [(1.0, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.12)] {
        b.add(tone(.sine, base * ratio, base * ratio * 0.995, dur, attack: 0.002, decay: dur * (1.1 - ratio / 12)), at: 0, gain: gain)
    }
    b.add(noiseBurst(0.02, lowpass: 0.6, highpass: 0.7), at: 0, gain: 0.4)
    return b
}

// MARK: - Effects

func midiHz(_ n: Int) -> Double { 440 * pow(2, Double(n - 69) / 12) }

/// A heavy steel module landing on steel: low thump plus a short metallic ring.
func steelThud(_ pitch: Double) -> Buffer {
    var b = tone(.sine, pitch, pitch * 0.5, 0.3)
    b.add(noiseBurst(0.12, lowpass: 0.1), at: 0, gain: 0.9)
    b.add(clink(pitch * 6.5, 0.3), at: 0.005, gain: 0.25)
    return b
}

// Hook release: latch clack and a short whoosh.
write("sfx_release", { var b = clink(1900, 0.08); b.add(noiseBurst(0.25, attack: 0.05, lowpass: 0.4, highpass: 0.6, curve: 1.5), at: 0.02, gain: 0.5); return b }(), gain: 0.5)
write("sfx_land", steelThud(130), gain: 0.75)
write("sfx_perfect", { var b = steelThud(150); b.add(clink(1568, 0.5), at: 0.03, gain: 0.6); b.add(clink(2093, 0.5), at: 0.09, gain: 0.5); return b }(), gain: 0.75)
// Rivet gun: rapid hammer bursts ending in a bright ping.
write("sfx_rivet", {
    var b = Buffer(0.45)
    for i in 0..<6 { b.add(noiseBurst(0.03, lowpass: 0.7, highpass: 0.5), at: Double(i) * 0.035, gain: 0.8) }
    b.add(clink(2400, 0.3), at: 0.22, gain: 0.7)
    return b
}(), gain: 0.6)
write("sfx_bent", { var b = tone(.saw, 420, 180, 0.35, curve: 0.7); lowpass(&b, 0.2); b.add(noiseBurst(0.05, lowpass: 0.5), at: 0, gain: 0.6); return b }(), gain: 0.5)
write("sfx_district", {
    var b = Buffer(0.8)
    for (i, n) in [72, 76, 79].enumerated() { b.add(clink(midiHz(n), 0.5), at: Double(i) * 0.09, gain: 0.8) }
    return b
}(), gain: 0.6)
write("sfx_penthouse", {
    var b = Buffer(1.3)
    for (i, n) in [72, 76, 79, 84].enumerated() { b.add(tone(.triangle, midiHz(n), midiHz(n), 0.5, attack: 0.01), at: Double(i) * 0.12, gain: 0.6) }
    for i in 0..<4 { b.add(clink(2200 + Double(i) * 200, 0.4), at: 0.5 + Double(i) * 0.06, gain: 0.4) }
    return b
}(), gain: 0.6)
write("sfx_collapse", {
    var b = Buffer(1.6)
    for i in 0..<6 { b.add(steelThud(110 - Double(i) * 8), at: Double(i) * 0.14, gain: 0.8 - Double(i) * 0.08) }
    b.add(noiseBurst(1.4, attack: 0.05, lowpass: 0.05, curve: 1.3), at: 0, gain: 0.8)
    return b
}(), gain: 0.8)
write("sfx_miss", { var b = noiseBurst(0.6, attack: 0.01, lowpass: 0.3, highpass: 0.4, curve: 1.2); b.add(tone(.sine, 600, 120, 0.6, curve: 0.8), at: 0, gain: 0.5); return b }(), gain: 0.55)
// Cable creak: slow, rough, wavering saw.
write("sfx_creak", { var b = tone(.saw, 140, 110, 0.6, attack: 0.05, vibrato: 30, vibRate: 13); lowpass(&b, 0.12); return b }(), gain: 0.55)
write("sfx_gust", { var b = noiseBurst(1.2, attack: 0.4, lowpass: 0.08, curve: 1.2); lowpass(&b, 0.3); return b }(), gain: 0.6)
write("sfx_shift", { var b = tone(.square, 880, 880, 0.12); lowpass(&b, 0.3); b.add({ var c = tone(.square, 660, 660, 0.16); lowpass(&c, 0.3); return c }(), at: 0.16, gain: 1); return b }(), gain: 0.35)
write("sfx_count", clink(880, 0.18), gain: 0.4)
write("sfx_go", { var b = tone(.square, 523, 523, 0.5, attack: 0.01); lowpass(&b, 0.25); return b }(), gain: 0.4)
write("sfx_tap", { var b = tone(.sine, 900, 700, 0.06); lowpass(&b, 0.5); return b }(), gain: 0.3)
write("sfx_buy", {
    var b = Buffer(0.6)
    for i in 0..<5 { b.add(clink(1000 + Double(i) * 140, 0.25), at: Double(i) * 0.05, gain: 0.7) }
    return b
}(), gain: 0.6)
write("sfx_gameover", {
    var b = Buffer(1.6)
    // Site whistle: two long notes.
    for (i, f) in [1046.0, 784].enumerated() { var w = tone(.sine, f, f, 0.55, attack: 0.03, vibrato: 6, vibRate: 7); lowpass(&w, 0.5); b.add(w, at: Double(i) * 0.6, gain: 0.7) }
    return b
}(), gain: 0.55)

// MARK: - Site ambience loop: wind, far traffic and the odd distant hammer.

do {
    let seconds = 12.0
    var b = Buffer(seconds)
    var wind = noiseBurst(seconds, attack: 0.001, lowpass: 0.02, curve: 0.0001)
    lowpass(&wind, 0.08)
    for i in 0..<wind.count { wind.s[i] *= 0.7 + 0.3 * sin(Double(i) / rate * 0.52 * .pi) }
    b.add(wind, at: 0, gain: 2.0)
    b.add(tone(.sine, 70, 70, seconds, attack: 0.001, decay: seconds * 40, vibrato: 1.5, vibRate: 0.2), at: 0, gain: 0.12)
    for t in [1.3, 1.55, 1.8, 5.9, 6.15, 9.4, 9.65, 9.9] { b.add(clink(1500, 0.18), at: t, gain: 0.05) }
    let fade = Int(0.4 * rate)
    for i in 0..<fade {
        let k = Double(i) / Double(fade)
        b.s[i] *= k
        b.s[b.count - 1 - i] *= k
    }
    write("ambience_site", b, gain: 0.45)
}
