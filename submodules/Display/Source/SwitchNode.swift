import Foundation
import UIKit
import AsyncDisplayKit

private final class SwitchNodeViewLayer: CALayer {
    override func setNeedsDisplay() {
    }
}

public protocol SwitchNodeViewProtocol: UIView {
    var isOn: Bool { get }
    var onTintColor: UIColor? { get set }
    var switchBackgroundColor: (color: UIColor, isDark: Bool) { get set }

    func setOn(_ isOn: Bool, animated: Bool)
    func setAction(_: @escaping (Bool) -> Void)
}

private final class SwitchNodeView: UISwitch, SwitchNodeViewProtocol {
    override class var layerClass: AnyClass {
        if #available(iOS 26.0, *) {
            return super.layerClass
        } else {
            return SwitchNodeViewLayer.self
        }
    }

    private var action: ((Bool) -> Void)?

    var switchBackgroundColor: (color: UIColor, isDark: Bool) = (.clear, false)

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addTarget(self, action: #selector(onAction), for: .valueChanged)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setAction(_ action: @escaping (Bool) -> Void) {
        self.action = action
    }

    @objc private func onAction() {
        action?(isOn)
    }
}

public final class CustomSwitchView: UIControl, SwitchNodeViewProtocol {
    private let background: UIView
    private let controlView: UIView
    private let controlContianerView: UIView
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private var dynamicSystem: DynamicSystem?

    private lazy var glassView: GlassView = {
        let glassView = GlassView(backgroundContentProvider: { [weak self] in
            guard let self else { return nil }

            let layer = controlView.layer.presentation() ?? controlView.layer
            let layerContainer = controlContianerView.layer.presentation() ?? controlContianerView.layer

            let frameSize = layer.convert(layer.frame, to: nil).size
            let layerFrame = CGRect(
                x: layerContainer.position.x - frameSize.width / 2.0,
                y: layerContainer.position.y - frameSize.height / 2.0,
                width: frameSize.width,
                height: frameSize.height
            )

            let additionalSize = CGSize(width: 16, height: 16)

            let size = CGSize(width: layerFrame.size.width + additionalSize.width, height: layerFrame.size.height + additionalSize.height)

            UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
            defer { UIGraphicsEndImageContext() }
            guard let context = UIGraphicsGetCurrentContext() else {
                return nil
            }

            context.setFillColor(switchBackgroundColor.color.cgColor)
            context.fill([CGRect(origin: .zero, size: size)])

            let offset = layerFrame.origin

            let bgLayer = self.background.layer.presentation() ?? self.background.layer

            context.translateBy(x: -offset.x + additionalSize.width / 2.0, y: -offset.y + additionalSize.height / 2.0)
            bgLayer.render(in: context)
            context.translateBy(x: offset.x - additionalSize.width / 2.0, y: offset.y - additionalSize.height / 2.0)

            guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }

            return (image, CGRect(origin: .zero, size: size))
        }, frameProvider: { [weak self] in
            guard let self else { return .zero }

            let layer = controlView.layer.presentation() ?? controlView.layer
            let layerContainer = controlContianerView.layer.presentation() ?? controlContianerView.layer

            let frameSize = layer.convert(layer.frame, to: nil).size
            let layerFrame = CGRect(
                x: layerContainer.position.x - frameSize.width / 2.0,
                y: layerContainer.position.y - frameSize.height / 2.0,
                width: frameSize.width,
                height: frameSize.height
            )

            self.glassContainerView.layer.cornerRadius = layerFrame.height / 2.0

            self.glassContainerView.frame = layerFrame
            self.glassView.layer.cornerRadius = layerFrame.height / 2.0
            return self.glassContainerView.bounds
        })

        glassView.p = 0.8
        glassView.glassHeight = 0.0
        glassView.maxEdgeBlur = 2
        glassView.alpha = 0

        glassView.innerShadowOpacity = 0.2
        glassView.innerShadowRadius = 4
        glassView.innerShadowOffset = CGSize(width: 0, height: 4)
        return glassView
    }()
    private lazy var glassContainerView: UIView = {
        let containerView = UIView()
        containerView.addSubview(glassView)

        return containerView
    }()

    private var longPressGesture: UILongPressGestureRecognizer?
    private var action: ((Bool) -> Void)?

    private var controlStartOffset: CGFloat = .zero
    private var gestureStartPoint: CGPoint = .zero
    private var gestureOffset: CGFloat = .zero
    private var gestureStartTime: CGFloat = .zero
    private var wasToggled: Bool = false

    private var controlFrame: CGRect = .zero

    public var isOn: Bool = false

    override public var tintColor: UIColor? {
        didSet {
            background.backgroundColor = tintColor
        }
    }

    public var onTintColor: UIColor? = .systemGreen {
        didSet {
            if isOn {
                background.backgroundColor = onTintColor
            }
        }
    }

    public var switchBackgroundColor: (color: UIColor, isDark: Bool) = (.clear, false) {
        didSet {
            glassView.isDarkThemeOverrided = switchBackgroundColor.isDark
        }
    }

    public init() {
        self.background = UIView()
        self.controlView = UIView()
        self.controlContianerView = UIView()

        super.init(frame: CGRect(origin: .zero, size: CGSize(width: 63, height: 28)))

        addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false
        background.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        background.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        background.topAnchor.constraint(equalTo: topAnchor).isActive = true
        background.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        background.layer.cornerRadius = 14
        background.layer.cornerCurve = .continuous

        addSubview(glassContainerView)
        glassContainerView.frame = CGRect(x: 2, y: 2, width: 38, height: 24)
        glassContainerView.layer.cornerRadius = 12

        glassContainerView.layer.shadowColor = UIColor.black.cgColor
        glassContainerView.layer.shadowOpacity = 0.1
        glassContainerView.layer.shadowOffset = CGSize(width: 0, height: 8)
        glassContainerView.layer.shadowRadius = 8

        glassView.frame = glassContainerView.bounds

        glassView.layer.cornerRadius = 12

        addSubview(controlContianerView)
        controlContianerView.addSubview(controlView)

        controlContianerView.frame = CGRect(x: 2, y: 2, width: 38, height: 24)
        controlFrame = controlContianerView.frame
        controlView.frame = controlContianerView.bounds
        controlView.layer.cornerRadius = controlFrame.height / 2.0

        controlView.backgroundColor = UIColor.white
        controlView.layer.cornerRadius = 12
        controlView.layer.cornerCurve = .continuous

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(onGesture(_:)))
        longPressGesture.minimumPressDuration = 0

        self.longPressGesture = longPressGesture
        addGestureRecognizer(longPressGesture)

        dynamicSystem = DynamicSystem(f: 2, z: 0.5, r: 0) { [weak self] in
            guard let self, let dynamicSystem else { return }

            let scale = max(-1, min(1, (((dynamicSystem.x - dynamicSystem.y) / 25.0))))

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            controlContianerView.layer.sublayerTransform = CATransform3DMakeScale(1 + 0.15 * scale, 1 / (1 + 0.15 * scale), 1)
            CATransaction.commit()
        }
    }


    private var currentOffset: CGFloat = .zero

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setOn(_ isOn: Bool, animated: Bool) {
        self.isOn = isOn

        controlFrame = isOn ? CGRect(x: frame.width - 40, y: 2, width: 38, height: 24) : CGRect(x: 2, y: 2, width: 38, height: 24)

        if animated {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 1, options: [.allowUserInteraction]) {
                self.controlContianerView.layer.position.x = self.controlFrame.center.x
                self.controlContianerView.layer.position.y = self.controlFrame.center.y
            }

            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]) {
                self.background.backgroundColor = isOn ? self.onTintColor : self.tintColor
            }
        } else {
            self.controlContianerView.layer.position.x = self.controlFrame.center.x
            self.controlContianerView.layer.position.y = self.controlFrame.center.y
            self.background.backgroundColor = isOn ? self.onTintColor : self.tintColor
        }
    }

    public func setAction(_ action: @escaping (Bool) -> Void) {
        self.action = action
    }

    private var startedIsOn: Bool = false

    @objc private func onGesture(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            startedIsOn = isOn

            feedbackGenerator.prepare()
            currentOffset = recognizer.location(in: self).x
            gestureStartTime = Date().timeIntervalSince1970
            gestureStartPoint = recognizer.location(in: self)
            self.glassView.alpha = 1
            wasToggled = false

            dynamicSystem?.start(value: controlFrame.center.x)

            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 1, options: [.allowUserInteraction]) {
                self.controlContianerView.transform = .identity.scaledBy(x: 1.5, y: 1.5)
                self.controlContianerView.layer.position.x = self.controlFrame.center.x
                self.controlContianerView.layer.position.y = self.controlFrame.center.y
            }

            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]) {
                self.controlView.alpha = 0
            }
        case .changed:
            gestureOffset = recognizer.location(in: self).x - gestureStartPoint.x

            let function: (CGFloat) -> CGFloat = { x in -1 / (x + 1) + 1 }

            var finalOffset = (isOn ? frame.width - 40 : 2) + gestureOffset

            if finalOffset < 2 {
                let delta = 2 - finalOffset
                finalOffset = 2 - function(delta / 30.0) * 8.0
            } else if finalOffset > frame.width - 40 {
                let delta = finalOffset - frame.width + 40
                finalOffset = frame.width - 40 + function(delta / 30.0) * 8.0
            }

            controlFrame.origin.x = finalOffset
            self.controlContianerView.layer.position = controlFrame.center
            currentOffset = recognizer.location(in: self).x

            dynamicSystem?.updateInput(x: controlFrame.center.x)

            if (controlFrame.origin.x < 4 && isOn) || (controlFrame.origin.x > frame.width - 42 && !isOn) {
                gestureStartPoint = recognizer.location(in: self)
                isOn.toggle()
                feedbackGenerator.impactOccurred()
                wasToggled = true
                UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]) {
                    self.background.backgroundColor = self.isOn ? self.onTintColor : self.tintColor
                }
            }

        case .ended:
            dynamicSystem?.stop()

            if !wasToggled {
                isOn.toggle()
                feedbackGenerator.impactOccurred()
            }

            if startedIsOn != isOn {
                action?(isOn)
            }

            controlFrame = isOn ? CGRect(x: frame.width - 40, y: 2, width: 38, height: 24) : CGRect(x: 2, y: 2, width: 38, height: 24)

            let delay: CGFloat
            if (Date().timeIntervalSince1970 - gestureStartTime) < 0.15 {
                delay = 0.2
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 1, options: [.allowUserInteraction]) {
                    self.controlContianerView.layer.position.x = self.controlFrame.center.x
                    self.controlContianerView.layer.position.y = self.controlFrame.center.y
                }

                UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                    self.glassView.alpha = 1
                    self.controlView.alpha = 0
                })

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut, .allowUserInteraction]) {
                        self.glassView.alpha = 0
                        self.controlView.alpha = 1
                    }
                }
            } else {
                delay = 0
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 1, options: [.allowUserInteraction]) {
                    self.controlContianerView.layer.position.x = self.controlFrame.center.x
                    self.controlContianerView.layer.position.y = self.controlFrame.center.y
                }

                UIView.animate(withDuration: 0.2, delay: delay, options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]) {
                    self.glassView.alpha = 0
                    self.controlView.alpha = 1
                }
            }

            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]) {
                self.background.backgroundColor = self.isOn ? self.onTintColor : self.tintColor
            }

            UIView.animate(withDuration: 0.2, delay: delay, options: delay > 0 ? [.beginFromCurrentState, .curveEaseInOut] : [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]) {
                self.controlContianerView.layer.transform = CATransform3DIdentity
                self.controlContianerView.layer.sublayerTransform = CATransform3DIdentity
            }

        case .cancelled, .failed:
            dynamicSystem?.stop()
            self.controlView.alpha = 1
            bringSubviewToFront(glassContainerView)

            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]) {
                self.glassView.alpha = 0
                self.controlContianerView.transform = .identity
                self.controlContianerView.layer.sublayerTransform = CATransform3DIdentity
            }

            setOn(isOn, animated: true)
        case .recognized, .possible:
            break
        default:
            break
        }
    }
}


open class SwitchNode: ASDisplayNode {
    public var valueUpdated: ((Bool) -> Void)?
    
    public var frameColor = UIColor(rgb: 0xe0e0e0) {
        didSet {
            if self.isNodeLoaded {
                if oldValue != self.frameColor {
                    if let view = self.view as? SwitchNodeViewProtocol {
                        view.tintColor = self.frameColor
                    }
                }
            }
        }
    }
    public var handleColor = UIColor(rgb: 0xffffff) {
        didSet {
            if self.isNodeLoaded {
                //(self.view as! UISwitch).thumbTintColor = self.handleColor
            }
        }
    }
    public var contentColor = UIColor(rgb: 0x42d451) {
        didSet {
            if self.isNodeLoaded {
                if oldValue != self.contentColor {
                    if let view = self.view as? SwitchNodeViewProtocol {
                        view.onTintColor = self.contentColor
                    }
                }
            }
        }
    }

    public var switchBackgroundColor: (color: UIColor, isDark: Bool) = (.clear, false) {
        didSet {
            if self.isNodeLoaded {
                if oldValue != self.switchBackgroundColor {
                    if let view = self.view as? SwitchNodeViewProtocol {
                        view.switchBackgroundColor = switchBackgroundColor
                    }
                }
            }
        }
    }

    private var _isOn: Bool = false
    public var isOn: Bool {
        get {
            return self._isOn
        } set(value) {
            if (value != self._isOn) {
                self._isOn = value
                if self.isNodeLoaded {
                    if let view = self.view as? SwitchNodeViewProtocol {
                        view.setOn(value, animated: false)
                    }
                }
            }
        }
    }
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            if #available(iOS 26.0, *) {
                return SwitchNodeView()
            } else {
                return CustomSwitchView()
            }
        })
    }
    
    override open func didLoad() {
        super.didLoad()
        
        self.view.isAccessibilityElement = false

        if let view = self.view as? SwitchNodeViewProtocol {
            view.backgroundColor = self.backgroundColor
            view.tintColor = self.frameColor
            view.onTintColor = self.contentColor
            view.switchBackgroundColor = self.switchBackgroundColor

            view.setOn(self._isOn, animated: false)

            view.setAction { isOn in
                self._isOn = view.isOn
                self.valueUpdated?(view.isOn)
            }
        }
    }
    
    public func setOn(_ value: Bool, animated: Bool) {
        self._isOn = value
        if self.isNodeLoaded {
            if let view = self.view as? SwitchNodeViewProtocol {
                view.setOn(value, animated: animated)
            }
        }
    }
    
    override open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 63.0, height: 28.0)
    }
}
