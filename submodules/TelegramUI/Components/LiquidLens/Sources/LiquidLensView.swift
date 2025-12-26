import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

private final class RestingBackgroundView: UIVisualEffectView {
    var isDark: Bool?

    static func colorMatrix(isDark: Bool) -> [Float32] {
        if isDark {
            return [1.082, -0.113, -0.011, 0.0, 0.135, -0.034, 1.003, -0.011, 0.0, 0.135, -0.034, -0.113, 1.105, 0.0, 0.135, 0.0, 0.0, 0.0, 1.0, 0.0]
        } else {
            return [1.185, -0.05, -0.005, 0.0, -0.2, -0.015, 1.15, -0.005, 0.0, -0.2, -0.015, -0.05, 1.195, 0.0, -0.2, 0.0, 0.0, 0.0, 1.0, 0.0]
        }
    }

    init() {
        let effect = UIBlurEffect(style: .light)
        super.init(effect: effect)
        
        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }
        
        self.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isDark: Bool) {
        if self.isDark == isDark {
            return
        }
        self.isDark = isDark
        
        if let sublayer = self.layer.sublayers?[0], let _ = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false
            
            if let classValue = NSClassFromString("CAFilter") as AnyObject as? NSObjectProtocol {
                let makeSelector = NSSelectorFromString("filterWithName:")
                let filter = classValue.perform(makeSelector, with: "colorMatrix").takeUnretainedValue() as? NSObject
                
                if let filter {
                    var matrix: [Float32] = RestingBackgroundView.colorMatrix(isDark: isDark)
                    filter.setValue(NSValue(bytes: &matrix, objCType: "{CAColorMatrix=ffffffffffffffffffff}"), forKey: "inputColorMatrix")
                    sublayer.filters = [filter]
                    sublayer.setValue(1.0, forKey: "scale")
                }
            }
        }
    }
}

public final class LiquidLensView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var selectionX: CGFloat
        var selectionWidth: CGFloat
        var isDark: Bool
        var isLifted: Bool

        init(size: CGSize, selectionX: CGFloat, selectionWidth: CGFloat, isDark: Bool, isLifted: Bool) {
            self.size = size
            self.selectionX = selectionX
            self.selectionWidth = selectionWidth
            self.isLifted = isLifted
            self.isDark = isDark
        }
    }

    private struct LensParams: Equatable {
        var baseFrame: CGRect
        var isLifted: Bool

        init(baseFrame: CGRect, isLifted: Bool) {
            self.baseFrame = baseFrame
            self.isLifted = isLifted
        }
    }

    private let containerView: UIView
    private let backgroundContainerContainer: UIView
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    public var lensView: UIView?
    private let liftedContainerView: UIView
    public let contentView: UIView
    private let restingBackgroundView: RestingBackgroundView
    
    private var legacySelectionView: GlassBackgroundView.ContentImageView?
    private var fakeSelectionView = UIView()
    private var fakeSelectionContainerView = UIView()
    private var legacyContentMaskView: UIView?
    private var legacyContentMaskBlobView: UIView?
    private var legacyLiftedContentBlobMaskView: UIView?
    private var blurBackgroundMaskView: UIView?
    private var glassView: GlassView?
    private var glassBackgroundBlur: BlurredBackgroundView?
    private var glassViewContainer: UIView?

    private var dynamicSystem: DynamicSystem?

    private var needRedrawBackground: Bool = true
    private var renderedBackgroundImage: UIImage?

    public var selectedContentView: UIView {
        return self.liftedContainerView
    }

    private var params: Params?
    private var appliedLensParams: LensParams?
    private var isApplyingLensParams: Bool = false
    private var pendingLensParams: LensParams?

    private var liftedDisplayLink: SharedDisplayLinkDriver.Link?

    public var selectionX: CGFloat? {
        return self.params?.selectionX
    }

    public var selectionWidth: CGFloat? {
        return self.params?.selectionWidth
    }

    override public init(frame: CGRect) {
        self.containerView = UIView()
        
        self.backgroundContainerContainer = UIView()
        self.backgroundContainer = GlassBackgroundContainerView()
        
        self.backgroundView = GlassBackgroundView()
        
        self.contentView = UIView()
        self.liftedContainerView = UIView()

        self.restingBackgroundView = RestingBackgroundView()

        super.init(frame: frame)
        
        self.backgroundContainerContainer.addSubview(self.backgroundContainer)
        self.addSubview(self.backgroundContainerContainer)
        
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        self.backgroundView.contentView.addSubview(self.containerView)
        self.containerView.isUserInteractionEnabled = false
        
        if #available(iOS 26.0, *), !GlassBackgroundView.useCustomGlassImpl {
            if let viewClass = NSClassFromString("_UILiquidLensView") as AnyObject as? NSObjectProtocol {
                let allocSelector = NSSelectorFromString("alloc")
                let initSelector = NSSelectorFromString("initWithRestingBackground:")
                let objcAlloc = viewClass.perform(allocSelector).takeUnretainedValue()
                let instance = objcAlloc.perform(initSelector, with: UIView()).takeUnretainedValue()
                self.lensView = instance as? UIView
            }
        }
        
        if let lensView = self.lensView {
            self.backgroundContainer.layer.zPosition = 1
            lensView.layer.zPosition = 10.0
            
            self.liftedContainerView.addSubview(self.restingBackgroundView)
            
            self.containerView.addSubview(self.liftedContainerView)
            self.containerView.addSubview(lensView)
            self.containerView.addSubview(self.contentView)
            
            lensView.perform(NSSelectorFromString("setLiftedContainerView:"), with: self.backgroundContainer.contentView)
            lensView.perform(NSSelectorFromString("setLiftedContentView:"), with: self.liftedContainerView)
            lensView.perform(NSSelectorFromString("setOverridePunchoutView:"), with: self.contentView)
            
            do {
                let selector = NSSelectorFromString("setLiftedContentMode:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Int32) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, 1)
                }
            }
            
            do {
                let selector = NSSelectorFromString("setStyle:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Int32) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, 1)
                }
            }
            
            do {
                let selector = NSSelectorFromString("setWarpsContentBelow:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Bool) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, true)
                }
            }
            
            lensView.setValue(UIColor(white: 0.0, alpha: 0.1), forKey: "restingBackgroundColor")
        } else {
            let legacySelectionView = GlassBackgroundView.ContentImageView()
            self.legacySelectionView = legacySelectionView
            self.backgroundView.contentView.insertSubview(legacySelectionView, at: 0)
            
            let legacyContentMaskView = UIView()
            legacyContentMaskView.backgroundColor = .white
            self.legacyContentMaskView = legacyContentMaskView
            self.contentView.mask = legacyContentMaskView
            
            if let filter = CALayer.luminanceToAlpha() {
                legacyContentMaskView.layer.filters = [filter]
            }
            
            let legacyContentMaskBlobView = UIView()
            self.legacyContentMaskBlobView = legacyContentMaskBlobView
            legacyContentMaskView.addSubview(legacyContentMaskBlobView)
            
            self.containerView.addSubview(self.contentView)
            
            let legacyLiftedContentBlobMaskView = UIView()
            self.legacyLiftedContentBlobMaskView = legacyLiftedContentBlobMaskView
            self.liftedContainerView.mask = legacyLiftedContentBlobMaskView

            self.containerView.addSubview(self.liftedContainerView)

            let glassView = GlassView(
                backgroundContentProvider: { [weak self] in
                    guard let self, let glassView = self.glassView else { return nil }

                    let size: CGSize = glassView.frame.size

                    let fullSize = CGSize(width: size.width + 32, height: size.height + 32)

                    UIGraphicsBeginImageContextWithOptions(fullSize, true, UIScreen.main.scale)
                    defer { UIGraphicsEndImageContext() }
                    guard let context = UIGraphicsGetCurrentContext() else {
                        return nil
                    }

                    context.translateBy(x: 16 - glassView.frame.origin.x, y: 16 - glassView.frame.origin.y)
                    for subview in liftedContainerView.subviews {
                        let sublayer = subview.layer.presentation() ?? subview.layer
                        let origin = sublayer.frame.origin

                        context.translateBy(x: origin.x, y: origin.y)
                        context.scaleBy(x: sublayer.transform.m11, y: sublayer.transform.m11)
                        sublayer.render(in: context)
                        context.scaleBy(x: 1 / sublayer.transform.m11, y: 1 / sublayer.transform.m11)
                        context.translateBy(x: -origin.x, y: -origin.y)
                    }
                    context.translateBy(x: -16 + glassView.frame.origin.x, y: -16 + glassView.frame.origin.y)

                    guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }

                    return (image, CGRect(origin: CGPoint(x: 16, y: 16), size: size))
                }, frameProvider: { [weak self] in
                    guard let self else { return .zero }

                    let layer = fakeSelectionView.layer.presentation() ?? fakeSelectionView.layer
                    let layerContainer = fakeSelectionContainerView.layer.presentation() ?? fakeSelectionContainerView.layer

                    let frameSize = layer.convert(layer.frame, to: nil).size
                    let layerFrame = CGRect(
                        x: layerContainer.position.x - frameSize.width / 2.0,
                        y: layerContainer.position.y - frameSize.height / 2.0,
                        width: frameSize.width,
                        height: frameSize.height
                    )

                    let cornerRadius = min(layerFrame.width, layerFrame.height) / 2.0

                    let glassViewAlpha = (self.glassView?.layer.presentation() ?? self.glassView?.layer)?.opacity

                    self.glassView?.p = CGFloat(glassViewAlpha ?? 0) * 0.7
                    self.glassView?.frame = layerFrame
                    self.glassView?.layer.cornerRadius = cornerRadius
                    self.glassViewContainer?.layer.cornerRadius = cornerRadius
                    self.glassViewContainer?.layer.frame = layerFrame

                    let blurFrame = CGRect(origin: CGPoint(x: -16, y: -16), size: layerFrame.insetBy(dx: -16, dy: -16).size)

                    self.glassBackgroundBlur?.update(size: blurFrame.size, cornerRadius: 0, transition: .immediate)
                    self.glassBackgroundBlur?.frame = blurFrame
                    self.glassBackgroundBlur?.updateColor(color: .clear, enableBlur: true, forceKeepBlur: true, transition: .immediate)

                    legacyLiftedContentBlobMaskView.frame = layerFrame
                    legacyLiftedContentBlobMaskView.layer.cornerRadius = cornerRadius

                    legacyContentMaskBlobView.frame = layerFrame
                    legacyContentMaskBlobView.layer.cornerRadius = cornerRadius

                    legacySelectionView.frame = layerFrame
                    legacySelectionView.layer.cornerRadius = cornerRadius

                    self.blurBackgroundMaskView?.frame = CGRect(origin: CGPoint(x: 16, y: 16), size: layerFrame.size)
                    self.blurBackgroundMaskView?.layer.cornerRadius = cornerRadius

                    return layerFrame
                }
            )

            glassView.p = 0.7
            glassView.glassHeight = 0.0
            glassView.maxEdgeBlur = UIScreen.main.scale
            glassView.innerShadowOpacity = 0
            glassView.overlayEnabled = false
            glassView.alpha = 0

            self.glassView = glassView

            let glassViewContainer = UIView()
            glassViewContainer.layer.shadowColor = UIColor.black.cgColor
            glassViewContainer.layer.shadowOpacity = 0.2
            glassViewContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
            glassViewContainer.layer.shadowRadius = 8
            glassViewContainer.alpha = 0

            self.glassViewContainer = glassViewContainer

            let glassBackgroundBlur = BlurredBackgroundView(color: .black, enableBlur: true, customBlurRadius: 8.0)
            self.glassBackgroundBlur = glassBackgroundBlur

            self.backgroundView.addSubview(fakeSelectionContainerView)
            self.fakeSelectionContainerView.addSubview(fakeSelectionView)

            self.backgroundView.contentView.addSubview(glassView)
            self.backgroundView.contentView.addSubview(glassViewContainer)

            glassViewContainer.addSubview(glassBackgroundBlur)

            self.backgroundView.contentView.sendSubviewToBack(glassViewContainer)

            let blurBackgroundMaskView = UIView()
            blurBackgroundMaskView.backgroundColor = .black
            self.blurBackgroundMaskView = blurBackgroundMaskView
            glassBackgroundBlur.mask = blurBackgroundMaskView

            dynamicSystem = DynamicSystem(
                f: 2,
                z: 0.5,
                r: 0
            ) { [weak self] in
                guard let self, let dynamicSystem else { return }

                let scale = max(-1, min(1, (((dynamicSystem.x - dynamicSystem.y) / 50.0))))

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                fakeSelectionContainerView.layer.sublayerTransform = CATransform3DMakeScale(1 + 0.2 * scale, 1 / (1 + 0.2 * scale), 1)
                CATransaction.commit()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func finishInteraction() {
        backgroundView.triggerEffect(began: false)
    }

    public func update(size: CGSize, selectionX: CGFloat, selectionWidth: CGFloat, isDark: Bool, isLifted: Bool, transition: ComponentTransition) {
        let params = Params(size: size, selectionX: selectionX, selectionWidth: selectionWidth, isDark: isDark, isLifted: isLifted)
        if self.params == params {
            return
        }
        self.update(params: params, transition: transition)
    }

    private func update(transition: ComponentTransition) {
        guard let params = self.params else {
            return
        }
        self.update(params: params, transition: transition)
    }

    private func updateLens(params: LensParams, animated: Bool) {
        guard let lensView = self.lensView else {
            return
        }

        if self.isApplyingLensParams {
            self.pendingLensParams = params
            return
        }
        self.isApplyingLensParams = true
        let previousParams = self.appliedLensParams

        let transition: ComponentTransition = animated ? .easeInOut(duration: 0.3) : .immediate

        if previousParams?.isLifted != params.isLifted {
            let selector = NSSelectorFromString("setLifted:animated:alongsideAnimations:completion:")
            var shouldScheduleUpdate = false
            var didProcessUpdate = false
            self.pendingLensParams = params
            if let lensView = self.lensView, let method = lensView.method(for: selector) {
                typealias ObjCMethod = @convention(c) (AnyObject, Selector, Bool, Bool, @escaping () -> Void, AnyObject?) -> Void
                let function = unsafeBitCast(method, to: ObjCMethod.self)
                function(lensView, selector, params.isLifted, !transition.animation.isImmediate, { [weak self] in
                    guard let self else {
                        return
                    }
                    let liftedInset: CGFloat = params.isLifted ? 4.0 : -4.0
                    lensView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: params.baseFrame.width + liftedInset * 2.0, height: params.baseFrame.height + liftedInset * 2.0))
                    didProcessUpdate = true
                    if shouldScheduleUpdate {
                        DispatchQueue.main.async { [weak self] in
                            guard let self, let pendingLensParams = self.pendingLensParams else {
                                return
                            }
                            self.isApplyingLensParams = false
                            self.pendingLensParams = nil
                            self.updateLens(params: pendingLensParams, animated: !transition.animation.isImmediate)
                        }
                    }
                }, nil)
            }
            if didProcessUpdate {
                transition.animateView {
                    lensView.center = CGPoint(x: params.baseFrame.midX, y: params.baseFrame.midY)
                }
                self.pendingLensParams = nil
                self.isApplyingLensParams = false
            } else {
                shouldScheduleUpdate = true
            }
        } else {
            transition.animateView {
                let liftedInset: CGFloat = params.isLifted ? 4.0 : -4.0
                lensView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: params.baseFrame.width + liftedInset * 2.0, height: params.baseFrame.height + liftedInset * 2.0))
                lensView.center = CGPoint(x: params.baseFrame.midX, y: params.baseFrame.midY)
            }
            self.isApplyingLensParams = false
        }
    }

    private func updateLiftedLensPosition() {
        // Without this, the lens won't update its bouncing animations unless it's being moved
        if self.isApplyingLensParams {
            return
        }
        guard let lensView = self.lensView else {
            return
        }
        guard let params = self.appliedLensParams else {
            return
        }
        lensView.center = CGPoint(x: params.baseFrame.midX, y: params.baseFrame.midY)
    }


    private var lastIsLifted: Bool = false

    private func update(params: Params, transition: ComponentTransition) {
        let isFirstTime = self.params == nil
        let transition: ComponentTransition = isFirstTime ? .immediate : transition

        self.params = params

        transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(), size: params.size))
        transition.setFrame(view: self.backgroundContainerContainer, frame: CGRect(origin: CGPoint(), size: params.size))

        transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: params.size))
        self.backgroundContainer.update(size: params.size, isDark: params.isDark, transition: transition)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
        self.backgroundView.update(size: params.size, cornerRadius: params.size.height * 0.5, isDark: params.isDark, tintColor: GlassBackgroundView.TintColor.init(kind: .panel, color: UIColor(white: params.isDark ? 0.0 : 1.0, alpha: 0.6)), isInteractive: true, transition: transition)
        
        transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: params.size))
        transition.setFrame(view: self.liftedContainerView, frame: CGRect(origin: CGPoint(), size: params.size))

        let baseLensFrame = CGRect(origin: CGPoint(x: max(0.0, min(params.selectionX, params.size.width - params.selectionWidth)), y: 0.0), size: CGSize(width: params.selectionWidth, height: params.size.height))
        self.updateLens(params: LensParams(baseFrame: baseLensFrame, isLifted: params.isLifted), animated: !transition.animation.isImmediate)
        
        if let legacyContentMaskView = self.legacyContentMaskView {
            transition.setFrame(view: legacyContentMaskView, frame: CGRect(origin: CGPoint(), size: params.size))
        }
        if let legacyContentMaskBlobView, let legacyLiftedContentBlobMaskView, let legacySelectionView, let glassView, let glassViewContainer {
            let lensFrame = baseLensFrame.insetBy(dx: 4.0, dy: 4.0)

            legacyContentMaskBlobView.backgroundColor = .black
            legacyLiftedContentBlobMaskView.backgroundColor = .black
            legacySelectionView.backgroundColor = UIColor(white: params.isDark ? 1.0 : 0.0, alpha: params.isDark ? 0.1 : 0.075)

            if lensFrame.size != fakeSelectionView.layer.bounds.size {
                fakeSelectionView.layer.bounds = CGRect(origin: .zero, size: lensFrame.size)
                fakeSelectionView.layer.position = CGPoint(x: lensFrame.size.width / 2.0, y: lensFrame.size.height / 2.0)
                fakeSelectionContainerView.layer.bounds = CGRect(origin: .zero, size: lensFrame.size)
            }

            if lastIsLifted != params.isLifted {
                if params.isLifted {
                    dynamicSystem?.start(value: lensFrame.center.x)
                } else {
                    dynamicSystem?.stop()
                }

                UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 1, options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.fakeSelectionContainerView.transform = params.isLifted ? .identity.scaledBy(x: 1.2, y: 1.2) : .identity
                    self.fakeSelectionContainerView.layer.position.x = lensFrame.center.x
                    self.fakeSelectionContainerView.layer.position.y = lensFrame.center.y
                    if !params.isLifted {
                        self.fakeSelectionContainerView.layer.sublayerTransform = CATransform3DIdentity
                    }
                }

                lastIsLifted = params.isLifted
            } else {
                self.fakeSelectionContainerView.layer.position.x = lensFrame.center.x
                self.fakeSelectionContainerView.layer.position.y = lensFrame.center.y
                
                dynamicSystem?.updateInput(x: lensFrame.center.x)
            }

            let customTransition = ComponentTransition(animation: .curve(duration: 0.2, curve: .linear))

            customTransition.setAlpha(view: glassView, alpha: params.isLifted ? 1 : 0, delay: params.isLifted ? 0 : 0)
            customTransition.setAlpha(view: glassViewContainer, alpha: params.isLifted ? 1 : 0, delay: params.isLifted ? 0 : 0)

            customTransition.setAlpha(view: legacySelectionView, alpha: params.isLifted ? 0 : 1, delay: params.isLifted ? 0.0 : 0)
            customTransition.setAlpha(view: legacyLiftedContentBlobMaskView, alpha: params.isLifted ? 0 : 1, delay: params.isLifted ? 0.0 : 0)
        }

        transition.setFrame(view: self.restingBackgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
        self.restingBackgroundView.update(isDark: params.isDark)
        transition.setAlpha(view: self.restingBackgroundView, alpha: params.isLifted ? 0.0 : 1.0)

        if params.isLifted {
            if self.liftedDisplayLink == nil {
                self.liftedDisplayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateLiftedLensPosition()
                })
            }
        } else if let liftedDisplayLink = self.liftedDisplayLink {
            self.liftedDisplayLink = nil
            liftedDisplayLink.invalidate()
        }
    }
}
