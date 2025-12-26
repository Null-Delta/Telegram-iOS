//
//  GlassView.swift
//  liquid-ass
//
//  Created by Rustam Khakhuk on 06.12.2025.
//

import UIKit
import MetalKit
import QuartzCore

struct GlassUniforms {
    var radius: Float
    var aspectRatio: Float
    var uvOffset: SIMD2<Float>
    var uvScale: SIMD2<Float>
    var p: Float
    var height: Float
    var maxEdgeBlur: Float
    var _padding: Float = 0
}

// MARK: - CAGlassLayer

class CAGlassLayer: CAMetalLayer {

    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var backgroundTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?

    private var currentUVOffset: SIMD2<Float> = .zero
    private var currentUVScale: SIMD2<Float> = SIMD2<Float>(1, 1)
    private var lastImageSize: CGSize = .zero

    var blurRadius: CGFloat = 0
    var p: CGFloat = 1
    var glassHeight: CGFloat = 0
    var maxEdgeBlur: CGFloat = 0

    var backgroundContentProvider: (() -> (UIImage?, CGRect)?)?
    var cornerRadiusForGlass: CGFloat = 0

    override init() {
        super.init()
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let glassLayer = layer as? CAGlassLayer {
            self.commandQueue = glassLayer.commandQueue
            self.pipelineState = glassLayer.pipelineState
            self.backgroundTexture = glassLayer.backgroundTexture
            self.vertexBuffer = glassLayer.vertexBuffer
            self.currentUVOffset = glassLayer.currentUVOffset
            self.currentUVScale = glassLayer.currentUVScale
            self.lastImageSize = glassLayer.lastImageSize
            self.backgroundContentProvider = glassLayer.backgroundContentProvider
            self.cornerRadiusForGlass = glassLayer.cornerRadiusForGlass
            self.blurRadius = glassLayer.blurRadius
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal не поддерживается на этом устройстве")
        }

        self.device = metalDevice
        self.pixelFormat = .bgra8Unorm
        self.framebufferOnly = true
        self.isOpaque = false
        self.backgroundColor = UIColor.clear.cgColor
        self.contentsScale = UIScreen.main.scale
        self.needsDisplayOnBoundsChange = true
        self.presentsWithTransaction = true

        setupMetal()
    }

    private func setupMetal() {
        guard let device = device else { return }

        commandQueue = device.makeCommandQueue()

        let vertices: [Float] = [
            -1.0, -1.0,  0.0, 1.0,
             1.0, -1.0,  1.0, 1.0,
            -1.0,  1.0,  0.0, 0.0,
             1.0,  1.0,  1.0, 0.0
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: vertices.count * MemoryLayout<Float>.stride,
                                         options: [])

        let mainBundle = Bundle(for: CAGlassLayer.self)
        guard let path = mainBundle.path(forResource: "DisplayBundle", ofType: "bundle") else {
            return
        }
        guard let bundle = Bundle(path: path) else {
            return
        }

        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            print("Не удалось создать Metal library")
            return
        }

        let vertexFunction = library.makeFunction(name: "glass_vertex")
        let fragmentFunction = library.makeFunction(name: "glass_effect")

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 2
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 4
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Ошибка создания pipeline state: \(error)")
        }
    }

    private func updateBackgroundTexture() {
        guard let device = device else { return }

        let content = backgroundContentProvider?()
        let cgImage = content?.0?.cgImage
        guard let rect = content?.1 else { return }

        lastImageSize = cgImage.map { CGSize(width: $0.width, height: $0.height) } ?? lastImageSize

        let scale = UIScreen.main.scale
        let imageWidth = CGFloat(lastImageSize.width)
        let imageHeight = CGFloat(lastImageSize.height)

        currentUVOffset = SIMD2<Float>(
            Float(rect.origin.x * scale / imageWidth),
            Float(rect.origin.y * scale / imageHeight)
        )
        currentUVScale = SIMD2<Float>(
            Float(rect.width * scale / imageWidth),
            Float(rect.height * scale / imageHeight)
        )

        guard let cgImage else { return }

        let textureLoader = MTKTextureLoader(device: device)

        do {
            let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.shared.rawValue),
                .SRGB: false
            ])

            backgroundTexture = texture
        } catch {
            print("Ошибка создания текстуры: \(error)")
        }
    }

    override func display() {
        guard (presentation() ?? self).opacity != 0, let drawable = nextDrawable() else { return }

        updateBackgroundTexture()

        guard
              let pipelineState = pipelineState,
              let commandQueue = commandQueue,
              let backgroundTexture = backgroundTexture
        else {
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(backgroundTexture, index: 0)

        let width = Float(round(bounds.width))
        let height = Float(round(bounds.height))
        let aspectRatio = height / width
        var uniforms = GlassUniforms(
            radius: Float(cornerRadiusForGlass) / width,
            aspectRatio: aspectRatio,
            uvOffset: currentUVOffset,
            uvScale: currentUVScale,
            p: Float(p),
            height: Float(glassHeight),
            maxEdgeBlur: Float(maxEdgeBlur)
        )
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlassUniforms>.size, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
        drawable.present()
    }
}

// MARK: - GlassView

public class GlassView: UIView {
    override public class var layerClass: AnyClass {
        return CAGlassLayer.self
    }

    var glassLayer: CAGlassLayer {
        return layer as! CAGlassLayer
    }

    public var isDarkThemeOverrided: Bool = false {
        didSet {
            updateForeground()
        }
    }

    public var blurRadius: CGFloat = 0 {
        didSet {
            glassLayer.blurRadius = blurRadius
        }
    }

    public var p: CGFloat = 1 {
        didSet {
            glassLayer.p = p
        }
    }

    public var glassHeight: CGFloat = 0 {
        didSet {
            glassLayer.glassHeight = glassHeight
        }
    }

    public var maxEdgeBlur: CGFloat = 0 {
        didSet {
            glassLayer.maxEdgeBlur = maxEdgeBlur
        }
    }

    public var innerShadowRadius: CGFloat = 10 {
        didSet {
            updateInnerShadow()
        }
    }

    public var innerShadowOpacity: Float = 0.3 {
        didSet {
            updateInnerShadow()
        }
    }

    public var innerShadowColor: UIColor = .black {
        didSet {
            updateInnerShadow()
        }
    }

    public var innerShadowOffset: CGSize = .zero {
        didSet {
            updateInnerShadow()
        }
    }

    public var overlayEnabled: Bool = true {
        didSet {
            updateForeground()
        }
    }

    private var displayLink: CADisplayLink?

    private var overlayColorView: UIView
    private var innerShadowLayer: CAShapeLayer?
    private var strokeLayer: CAShapeLayer?

    var frameProvider: (() -> (CGRect))?

    public init(
        backgroundContentProvider: @escaping () -> (UIImage?, CGRect)?,
        frameProvider: (() -> (CGRect))?
    ) {
        overlayColorView = UIView()
        self.frameProvider = frameProvider

        super.init(frame: .zero)

        glassLayer.backgroundContentProvider = backgroundContentProvider

        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true

        layer.cornerCurve = .continuous

        addSubview(overlayColorView)
        overlayColorView.backgroundColor = .clear
        overlayColorView.translatesAutoresizingMaskIntoConstraints = false
        overlayColorView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        overlayColorView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        overlayColorView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        overlayColorView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        setupDisplayLink()
        setupInnerShadow()
        setupStrokeLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupInnerShadow() {
        let shadowLayer = CAShapeLayer()
        shadowLayer.masksToBounds = true
        layer.addSublayer(shadowLayer)
        innerShadowLayer = shadowLayer
    }

    private func setupStrokeLayer() {
        let strokeLayer = CAShapeLayer()
        strokeLayer.masksToBounds = true
        layer.addSublayer(strokeLayer)
        strokeLayer.opacity = 0.5

        self.strokeLayer = strokeLayer
    }

    deinit {
        displayLink?.invalidate()
    }

    private func setupDisplayLink() {
        let displayLink = CADisplayLink(target: self, selector: #selector(self.displayLinkFired))

        if #available(iOS 15.0, *) {
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        }

        displayLink.add(to: .current, forMode: .common)
        self.displayLink = displayLink
    }

    @objc private func displayLinkFired() {
        if let frameProvider {
            CATransaction.begin()
            CATransaction.setDisableActions(true)

            self.frame = frameProvider()

            CATransaction.commit()
        }

        updateInnerShadow()
        updateStrokeLayer()
        glassLayer.setNeedsDisplay()
    }

    private func updateInnerShadow() {
        guard let shadowLayer = innerShadowLayer else { return }

        let currentBounds = bounds
        let currentCornerRadius = bounds.height / 2.0

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        shadowLayer.frame = currentBounds

        let inset: CGFloat = -innerShadowRadius * 2
        let shadowPath = UIBezierPath(
            roundedRect: currentBounds.insetBy(dx: inset, dy: inset),
            cornerRadius: currentCornerRadius
        )

        let cutout = UIBezierPath(roundedRect: currentBounds.insetBy(dx: -4, dy: -4),
                                  cornerRadius: currentCornerRadius).reversing()

        shadowPath.append(cutout)

        shadowLayer.path = shadowPath.cgPath
        shadowLayer.fillColor = innerShadowColor.cgColor
        shadowLayer.shadowColor = innerShadowColor.cgColor
        shadowLayer.shadowOffset = innerShadowOffset
        shadowLayer.shadowOpacity = innerShadowOpacity
        shadowLayer.shadowRadius = innerShadowRadius

        CATransaction.commit()
    }

    private func updateStrokeLayer() {
        guard let strokeLayer else { return }

        let currentBounds = bounds
        let currentCornerRadius = bounds.height / 2.0

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        strokeLayer.frame = currentBounds

        let path = UIBezierPath(
            roundedRect: currentBounds,
            cornerRadius: currentCornerRadius
        )

        strokeLayer.path = path.cgPath
        strokeLayer.strokeColor = UIColor.white.cgColor
        strokeLayer.lineWidth = 2
        strokeLayer.fillColor = UIColor.clear.cgColor

        let mask = CAGradientLayer()
        mask.frame = currentBounds
        mask.type = .axial
        mask.startPoint = CGPoint(x: 0, y: 0)
        mask.endPoint = CGPoint(x: 1, y: 1)
        mask.colors = [
            UIColor.white.cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.cgColor
        ]

        strokeLayer.mask = mask

        strokeLayer.opacity = isDarkThemeOverrided || traitCollection.userInterfaceStyle == .dark ? 0.5 : 1.0

        CATransaction.commit()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateForeground()
    }

    private func updateForeground() {
        updateStrokeLayer()

        if overlayEnabled {
            overlayColorView.backgroundColor = traitCollection.userInterfaceStyle == .dark || isDarkThemeOverrided ? UIColor.white.withAlphaComponent(0.1) : .clear
        } else {
            overlayColorView.backgroundColor = .clear
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        updateForeground()

        glassLayer.frame = frame

        if bounds.size != .zero {
            glassLayer.drawableSize = CGSize(
                width: bounds.width * UIScreen.main.scale,
                height: bounds.height * UIScreen.main.scale
            )
        }
        glassLayer.cornerRadiusForGlass = layer.cornerRadius
    }

    override public var frame: CGRect {
        didSet {
            glassLayer.frame = frame
            if bounds.size != .zero {
                glassLayer.drawableSize = CGSize(
                    width: bounds.width * UIScreen.main.scale,
                    height: bounds.height * UIScreen.main.scale
                )
            }
        }
    }
}
