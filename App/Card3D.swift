import SwiftUI
import SceneKit
import UIKit

/// Text printed on the card faces.
struct CardInfo: Equatable {
    var label: String          // "مصروف اليوم"
    var amount: String         // "180.00"
    var currency: String       // "ر.ق"
    var digits: String         // last card digits
    var rtl: Bool
    var backTitle1: String, backValue1: String   // this cycle
    var backTitle2: String, backValue2: String   // daily average
}

/// The approved maroon metal card, rendered in real 3D. Drag to tilt, tap to flip.
struct Card3DView: UIViewRepresentable {
    var info: CardInfo

    func makeUIView(context: Context) -> CardSceneView {
        let v = CardSceneView()
        v.update(info)
        return v
    }

    func updateUIView(_ v: CardSceneView, context: Context) { v.update(info) }
}

final class CardSceneView: SCNView, UIGestureRecognizerDelegate {
    private let W: CGFloat = 3.37, H: CGFloat = 2.125, D: CGFloat = 0.05, R: CGFloat = 0.16
    private let camNode = SCNNode()
    private let pivot = SCNNode()   // tilt (drag, sway)
    private let card = SCNNode()    // flip
    private let frontMat = SCNMaterial(), backMat = SCNMaterial()
    private var current: CardInfo?
    private var flipped = false
    private let base = SCNVector3(0.2, -0.3, 0.03)
    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    init() {
        super.init(frame: .zero, options: nil)
        // in a frozen screenshot pose the stage is tinted, so a cut-off edge would be visible against it
        backgroundColor = Demo.cardPose == nil ? .clear : UIColor(red: 0, green: 1, blue: 0, alpha: 0.18)
        isOpaque = false
        antialiasingMode = .multisampling4X
        rendersContinuously = false
        preferredFramesPerSecond = 60
        isAccessibilityElement = true
        accessibilityTraits = .button
        build()
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Scene

    private func pbr(_ color: UIColor, metal: CGFloat, rough: CGFloat, coat: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.metalness.contents = metal
        m.roughness.contents = rough
        m.clearCoat.contents = coat
        m.clearCoatRoughness.contents = 0.12
        return m
    }

    private func build() {
        let s = SCNScene()
        s.lightingEnvironment.contents = Self.studioEnvironment()
        s.lightingEnvironment.intensity = 1.25

        let cam = SCNCamera()
        cam.fieldOfView = 20
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0, 7.8)
        s.rootNode.addChildNode(camNode)
        pointOfView = camNode

        let key = SCNLight(); key.type = .directional; key.intensity = 1400; key.color = UIColor.white
        let keyNode = SCNNode(); keyNode.light = key; keyNode.position = SCNVector3(-3, 4, 5); keyNode.look(at: SCNVector3Zero)
        let rim = SCNLight(); rim.type = .directional; rim.intensity = 700; rim.color = UIColor(red: 1, green: 0.84, blue: 0.75, alpha: 1)
        let rimNode = SCNNode(); rimNode.light = rim; rimNode.position = SCNVector3(4, -2, -3); rimNode.look(at: SCNVector3Zero)
        s.rootNode.addChildNode(keyNode)
        s.rootNode.addChildNode(rimNode)

        // body: extruded rounded rectangle
        let path = UIBezierPath(roundedRect: CGRect(x: -W / 2, y: -H / 2, width: W, height: H), cornerRadius: R)
        path.flatness = 0.002
        let body = SCNShape(path: path, extrusionDepth: D)
        body.chamferRadius = 0.01
        body.materials = [pbr(UIColor(red: 0.29, green: 0.04, blue: 0.12, alpha: 1), metal: 0.85, rough: 0.32, coat: 0.6)]
        card.addChildNode(SCNNode(geometry: body))

        // printed faces
        for (mat, z, flip) in [(frontMat, D / 2 + 0.0015, false), (backMat, -(D / 2 + 0.0015), true)] {
            mat.lightingModel = .physicallyBased
            mat.metalness.contents = 0.45
            mat.roughness.contents = 0.4
            mat.clearCoat.contents = 1.0
            mat.clearCoatRoughness.contents = 0.12
            let plane = SCNPlane(width: W - 0.012, height: H - 0.012)
            plane.cornerRadius = R - 0.006
            plane.materials = [mat]
            let n = SCNNode(geometry: plane)
            n.position = SCNVector3(0, 0, Float(z))
            if flip { n.eulerAngles.y = .pi }
            card.addChildNode(n)
        }

        // gold chip
        let chipPath = UIBezierPath(roundedRect: CGRect(x: -0.22, y: -0.17, width: 0.44, height: 0.34), cornerRadius: 0.05)
        let chip = SCNShape(path: chipPath, extrusionDepth: 0.014)
        chip.chamferRadius = 0.004
        chip.materials = [pbr(UIColor(red: 0.89, green: 0.76, blue: 0.56, alpha: 1), metal: 1, rough: 0.24)]
        let chipNode = SCNNode(geometry: chip)
        chipNode.position = SCNVector3(Float(-W / 2 + 0.62), 0.12, Float(D / 2 + 0.008))
        card.addChildNode(chipNode)

        pivot.addChildNode(card)
        s.rootNode.addChildNode(pivot)
        scene = s

        if reduceMotion {
            pivot.eulerAngles = base
        } else { // intro: grows and turns into place, then a gentle sway that settles (stays inside the stage).
                 // Fully visible from the first frame, so a slow first render never leaves the stage empty.
            pivot.scale = SCNVector3(0.92, 0.92, 0.92)
            pivot.eulerAngles = SCNVector3(base.x, base.y - 0.3, base.z)
            let intro = SCNAction.group([SCNAction.scale(to: 1, duration: 0.6),
                                         SCNAction.rotateTo(x: CGFloat(base.x), y: CGFloat(base.y), z: CGFloat(base.z), duration: 0.6, usesShortestUnitArc: true)])
            intro.timingMode = .easeOut
            pivot.runAction(SCNAction.sequence([intro, sway()]), forKey: "intro")
        }
        if let pose = Demo.cardPose { // screenshot checks: a frozen pose (flip angle in degrees, optional drag)
            pivot.removeAllActions(); pivot.scale = SCNVector3(1, 1, 1)
            pivot.eulerAngles = SCNVector3(base.x + pose.pitch, base.y + pose.yaw, base.z)
            let k = Float(pose.scale)
            card.scale = SCNVector3(k, k, k)
            card.eulerAngles.y = Float(pose.flip * .pi / 180)
        }
    }

    /// The card's motion limits. The camera distance in `layoutSubviews` is worked out so that every pose
    /// these allow (sway, drag, flip, intro) stays inside the view: no edge of the card is ever cut off.
    private enum Limit {
        static let yaw: Float = 0.25        // horizontal drag
        static let pitch: Float = 0.06      // vertical component of a drag
        static let flipScale: CGFloat = 0.78
    }

    private func sway() -> SCNAction {
        let steps: [(CGFloat, Double)] = [(0.12, 1.4), (-0.08, 1.4), (0.05, 1.2), (0, 1.0)]
        let actions = steps.map { step -> SCNAction in
            let a = SCNAction.rotateTo(x: CGFloat(base.x), y: CGFloat(base.y) + step.0, z: CGFloat(base.z), duration: step.1, usesShortestUnitArc: true)
            a.timingMode = .easeInEaseOut
            return a
        }
        return SCNAction.sequence(actions)
    }

    /// As large as the view allows while the widest pose still fits (checked by projecting the card's corners for
    /// every sway, drag, flip and intro frame): at rest the card fills ~84% of the stage height.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.height > 0 else { return }
        let t = tan(10.0 * Double.pi / 180)              // half of the 20° field of view
        let aspect = Double(bounds.width / bounds.height)
        let fitHeight = 2.76 / (2 * t)
        let fitWidth = 3.70 / (2 * t * aspect)
        camNode.position = SCNVector3(0, 0, Float(max(fitHeight, fitWidth)))
    }

    // MARK: Faces

    func update(_ info: CardInfo) {
        guard info != current else { return }
        current = info
        frontMat.diffuse.contents = Self.drawFront(info)
        backMat.diffuse.contents = Self.drawBack(info)
        accessibilityLabel = info.label + " " + info.amount + " " + info.currency
    }

    private static let size = CGSize(width: 1024, height: 646)

    private static func brushed(_ ctx: CGContext, _ colors: [UIColor]) {
        let cs = CGColorSpaceCreateDeviceRGB()
        if let g = CGGradient(colorsSpace: cs, colors: colors.map(\.cgColor) as CFArray, locations: [0, 0.5, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        var seed: UInt64 = 7
        func next() -> CGFloat { seed = (seed &* 16807) % 2147483647; return CGFloat(seed) / 2147483647 }
        for _ in 0..<1400 {
            let a = next() * 0.045, y = next() * size.height
            ctx.setFillColor(UIColor(white: 1, alpha: a).cgColor)
            ctx.fill(CGRect(x: 0, y: y, width: size.width, height: 1))
        }
    }

    private static func font(_ name: String, _ size: CGFloat) -> UIFont { UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .semibold) }

    private static func draw(_ text: String, _ font: UIFont, _ color: UIColor, in rect: CGRect, align: NSTextAlignment, rtl: Bool) {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        p.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
        p.lineBreakMode = .byClipping
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: p])
    }

    static func drawFront(_ i: CardInfo) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { r in
            let ctx = r.cgContext
            brushed(ctx, [UIColor(red: 0.36, green: 0.05, blue: 0.15, alpha: 1), UIColor(red: 0.54, green: 0.08, blue: 0.22, alpha: 1),
                          UIColor(red: 0.24, green: 0.04, blue: 0.10, alpha: 1)])
            let gold = UIColor(red: 0.93, green: 0.83, blue: 0.65, alpha: 1)
            let ink = UIColor(red: 0.97, green: 0.91, blue: 0.78, alpha: 1)
            let soft = UIColor(red: 0.97, green: 0.93, blue: 0.89, alpha: 0.88)
            draw("مصروفي", font("Alexandria-Bold", 60), gold, in: CGRect(x: 380, y: 52, width: 584, height: 84), align: .right, rtl: true)
            ctx.setStrokeColor(gold.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(7); ctx.setLineCap(.round)
            for k in 0..<3 {
                let p = UIBezierPath(arcCenter: CGPoint(x: 78, y: 92), radius: CGFloat(16 + k * 15), startAngle: -0.85, endAngle: 0.85, clockwise: true)
                ctx.addPath(p.cgPath); ctx.strokePath()
            }
            draw(i.label, font("Alexandria-Regular", 34), soft, in: CGRect(x: 300, y: 428, width: 664, height: 50), align: i.rtl ? .right : .left, rtl: i.rtl)
            let amountFont = font("Alexandria-SemiBold", 112)
            let amountWidth = (i.amount as NSString).size(withAttributes: [.font: amountFont]).width
            draw(i.amount, amountFont, ink, in: CGRect(x: 964 - amountWidth, y: 476, width: amountWidth + 4, height: 140), align: .left, rtl: false)
            let curFont = font("Alexandria-Medium", 36)
            let curWidth = (i.currency as NSString).size(withAttributes: [.font: curFont]).width
            draw(i.currency, curFont, soft, in: CGRect(x: 964 - amountWidth - 18 - curWidth, y: 546, width: curWidth + 4, height: 50), align: .left, rtl: false)
            draw("•••• " + i.digits, font("Alexandria-Medium", 40), soft, in: CGRect(x: 64, y: 544, width: 300, height: 56), align: .left, rtl: false)
        }
    }

    static func drawBack(_ i: CardInfo) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { r in
            let ctx = r.cgContext
            brushed(ctx, [UIColor(red: 0.24, green: 0.04, blue: 0.10, alpha: 1), UIColor(red: 0.36, green: 0.05, blue: 0.15, alpha: 1),
                          UIColor(red: 0.18, green: 0.03, blue: 0.07, alpha: 1)])
            ctx.setFillColor(UIColor(white: 0.04, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 0, y: 70, width: size.width, height: 110))
            let soft = UIColor(red: 0.97, green: 0.93, blue: 0.89, alpha: 0.85)
            let ink = UIColor(red: 0.97, green: 0.91, blue: 0.78, alpha: 1)
            let leftRect = CGRect(x: 64, y: 400, width: 440, height: 50), rightRect = CGRect(x: 520, y: 400, width: 444, height: 50)
            draw(i.backTitle1, font("Alexandria-Regular", 32), soft, in: i.rtl ? rightRect : leftRect, align: i.rtl ? .right : .left, rtl: i.rtl)
            draw(i.backTitle2, font("Alexandria-Regular", 32), soft, in: i.rtl ? leftRect : rightRect, align: i.rtl ? .left : .right, rtl: i.rtl)
            let v1 = i.rtl ? CGRect(x: 520, y: 450, width: 444, height: 100) : CGRect(x: 64, y: 450, width: 440, height: 100)
            let v2 = i.rtl ? CGRect(x: 64, y: 450, width: 440, height: 100) : CGRect(x: 520, y: 450, width: 444, height: 100)
            draw(i.backValue1, font("Alexandria-SemiBold", 76), ink, in: v1, align: i.rtl ? .right : .left, rtl: false)
            draw(i.backValue2, font("Alexandria-SemiBold", 76), ink, in: v2, align: i.rtl ? .left : .right, rtl: false)
        }
    }

    /// Soft studio light used for the metal reflections.
    static func studioEnvironment() -> UIImage {
        let s = CGSize(width: 512, height: 256)
        return UIGraphicsImageRenderer(size: s).image { r in
            let ctx = r.cgContext, cs = CGColorSpaceCreateDeviceRGB()
            let sky = CGGradient(colorsSpace: cs, colors: [UIColor(white: 0.55, alpha: 1).cgColor, UIColor(white: 0.12, alpha: 1).cgColor, UIColor(white: 0.05, alpha: 1).cgColor] as CFArray, locations: [0, 0.55, 1])!
            ctx.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
            for (x, y, rad, a) in [(120.0, 70.0, 70.0, 0.95), (330.0, 60.0, 55.0, 0.8), (430.0, 150.0, 40.0, 0.5)] {
                let g = CGGradient(colorsSpace: cs, colors: [UIColor(white: 1, alpha: CGFloat(a)).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
                ctx.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: CGFloat(rad), options: [])
            }
        }
    }

    // MARK: Interaction

    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard let pan = g as? UIPanGestureRecognizer else { return true }
        if card.action(forKey: "flip") != nil { return false }   // no tilting while the card turns over
        let v = pan.velocity(in: self)
        return abs(v.x) > abs(v.y) // vertical drags keep scrolling the page
    }

    /// Brings the card to full size (if the intro was interrupted) and back to its resting tilt.
    private func settle(_ duration: TimeInterval, key: String) {
        let d = reduceMotion ? 0.01 : duration
        let back = SCNAction.group([SCNAction.scale(to: 1, duration: d),
                                    SCNAction.rotateTo(x: CGFloat(base.x), y: CGFloat(base.y), z: CGFloat(base.z), duration: d, usesShortestUnitArc: true)])
        back.timingMode = .easeOut
        pivot.runAction(back, forKey: key)
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: self)
        switch g.state {
        case .began:
            pivot.removeAllActions()
            pivot.runAction(SCNAction.scale(to: 1, duration: 0.15))
        case .changed:
            // rubber band: follows the finger, then resists, never past the limits the camera was fitted for
            let yaw = Limit.yaw * tanh(Float(t.x) * 0.01 / Limit.yaw)
            let pitch = Limit.pitch * tanh(Float(t.y) * 0.004 / Limit.pitch)
            pivot.eulerAngles = SCNVector3(base.x + pitch, base.y + yaw, base.z)
        default:
            settle(0.5, key: "back")
        }
    }

    @objc private func onTap() {
        flipped.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pivot.removeAllActions()
        settle(0.25, key: "back")   // straighten up first, so the turning card stays inside the stage
        let turn = SCNAction.rotateTo(x: 0, y: flipped ? .pi : 0, z: 0, duration: reduceMotion ? 0.01 : 0.6, usesShortestUnitArc: false)
        turn.timingMode = .easeInEaseOut
        if reduceMotion {
            card.runAction(turn, forKey: "flip")
        } else { // lifts slightly away while it turns, like a card picked up and turned over
            let lift = SCNAction.sequence([SCNAction.scale(to: Limit.flipScale, duration: 0.3), SCNAction.scale(to: 1, duration: 0.3)])
            card.runAction(SCNAction.group([turn, lift]), forKey: "flip")
        }
    }
}
