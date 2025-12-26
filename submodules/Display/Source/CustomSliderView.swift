//
//  CustomSliderView.swift
//  Telegram
//
//  Created by Rustam Khakhuk on 21.12.2025.
//

import UIKit

public final class CustomSliderView: UIView {
    public var backColor: UIColor? = .clear {
        didSet {
            backgroundLine.backgroundColor = backColor
            dotsStackView.arrangedSubviews.forEach {
                $0.backgroundColor = backColor
            }
        }
    }

    public var trackColor: UIColor? = .white {
        didSet {
            foregroundLine.backgroundColor = trackColor
        }
    }

    public var minimumValue: CGFloat = 0
    public var maximumValue: CGFloat = 1

    public var value: CGFloat {
        let progress = finalProgress(for: progress)
        return minimumValue + (maximumValue - minimumValue) * progress
    }

    public var controlPointsCount: Int = 0 {
        didSet {
            guard controlPointsCount != oldValue else { return }

            dotsStackView.arrangedSubviews.forEach {
                dotsStackView.removeArrangedSubview($0)
                $0.removeFromSuperview()
            }

            updateDotsStackSpacing()

            for _ in 0..<controlPointsCount {
                let dotView = UIView()
                dotView.frame = CGRect(origin: .zero, size: CGSize(width: 4, height: 4))
                dotView.layer.cornerRadius = 2
                dotView.backgroundColor = backColor

                dotsStackView.addArrangedSubview(dotView)
            }
        }
    }

    public var onUpdate: ((CGFloat) -> Void)?

    public var isDarkAppearanceOverrided: Bool = false {
        didSet {
            glassView.isDarkThemeOverrided = isDarkAppearanceOverrided
        }
    }

    public var isTracking: Bool {
        wasGestureStarted
    }

    public var limitValueChangedToLatestState: Bool = false

    private var progress: CGFloat = 0

    private func interpolatedProgress(for value: CGFloat) -> CGFloat {
        let value = max(0, min(1, value))

        if controlPointsCount != 0 {
            let partSize = 1.0 / CGFloat(controlPointsCount - 1)
            let partsCount = floor(value / partSize)
            let partProgress = (value - partsCount * partSize) / partSize

            return partsCount * partSize + discreteProgress(for: partProgress) * partSize
        } else {
            return progress
        }
    }

    private func discreteProgress(for value: CGFloat) -> CGFloat {
        let p = 4.0
        if value < 0.5 {
            return pow(value * 2.0, p) / 2.0
        } else {
            return 1 - pow(2.0 * abs(value - 1), p) / 2.0
        }
    }

    private func finalProgress(for value: CGFloat) -> CGFloat {
        let value = max(0, min(1, value))
        
        if controlPointsCount != 0 {
            let partSize = 1.0 / CGFloat(controlPointsCount - 1)
            var partsCount = floor(value / partSize)
            let partProgress = (value - partsCount * partSize) / partSize

            if partProgress > 0.5 {
                partsCount += 1
            }

            return partsCount * partSize
        } else {
            return progress
        }
    }

    private var controlFrame: CGRect {
        CGRect(
            x: 19 + (frame.width - 38) * min(1, max(0, interpolatedProgress(for: progress))) - 19,
            y: frame.height / 2.0 - 12,
            width: 38,
            height: 24
        )
    }

    private let backgroundLine = UIView()
    private let foregroundLine = UIView()
    private let controlView = UIView()
    private let controlContainerView = UIView()

    private let dotsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill

        return stackView
    }()

    private lazy var glassView: GlassView = {
        let glassView = GlassView(
            backgroundContentProvider: { [weak self] in
                guard let self else { return nil }

                let size = CGSize(width: frame.width + 32, height: frame.height + 32)

                UIGraphicsBeginImageContextWithOptions(size, true, UIScreen.main.scale)
                defer { UIGraphicsEndImageContext() }
                guard let context = UIGraphicsGetCurrentContext() else {
                    return nil
                }

                context.setFillColor((self.backgroundColor ?? .clear).cgColor)
                context.fill([CGRect(origin: .zero, size: size)])

                let views = [
                    backgroundLine,
                    dotsStackView
                ]

                for view in views {
                    context.translateBy(x: 16 + view.frame.origin.x, y:  16 + view.frame.origin.y)
                    view.layer.render(in: context)
                    context.translateBy(x: -16 - view.frame.origin.x, y: -16 - view.frame.origin.y)
                }

                guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }

                return (
                    image,
                    CGRect(
                        origin: CGPoint(x: self.glassView.frame.origin.x + 16, y: self.glassView.frame.origin.y + 16),
                        size: self.glassView.frame.size
                    )
                )
            },
            frameProvider: { [weak self] in
                guard let self else { return .zero }

                let layer = controlView.layer.presentation() ?? controlView.layer
                let layerContainer = controlContainerView.layer.presentation() ?? controlContainerView.layer

                let frameSize = layer.convert(layer.frame, to: nil).size
                let layerFrame = CGRect(
                    x: layerContainer.position.x - frameSize.width / 2.0,
                    y: layerContainer.position.y - frameSize.height / 2.0,
                    width: frameSize.width,
                    height: frameSize.height
                )

                self.glassView.frame = layerFrame
                self.glassView.layer.cornerRadius = layerFrame.height / 2.0

                self.glassViewContainer.frame = layerFrame
                self.glassViewContainer.layer.cornerRadius = layerFrame.height / 2.0

                self.glassViewContainer.layer.shadowPath = UIBezierPath(roundedRect: glassViewContainer.bounds, cornerRadius: glassViewContainer.bounds.height / 2.0).cgPath

                self.updateForegroundLineFrame(for: self.progress)
                return layerFrame
            }
        )

        glassView.innerShadowOffset = CGSize(width: 0, height: 4)
        glassView.innerShadowRadius = 4
        glassView.innerShadowOpacity = 0.2

        glassView.p = 0.8
        glassView.glassHeight = 0.0
        glassView.maxEdgeBlur = UIScreen.main.scale

        return glassView
    }()
    private var glassViewContainer = UIView()

    private var gesture: UILongPressGestureRecognizer?
    private var panGesture: UIPanGestureRecognizer?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private var dynamicSystem: DynamicSystem?

    private var startValue: CGFloat = .zero

    public init() {
        super.init(frame: .zero)

        addSubview(backgroundLine)
        backgroundLine.addSubview(foregroundLine)
        addSubview(dotsStackView)
        addSubview(controlContainerView)
        controlContainerView.addSubview(controlView)
        addSubview(glassViewContainer)
        addSubview(glassView)

        glassView.alpha = 0

        controlView.layer.shadowColor = UIColor.black.cgColor
        controlView.layer.shadowOffset = CGSize(width: 0, height: 6)
        controlView.layer.shadowRadius = 12
        controlView.layer.shadowOpacity = 0.1
        controlView.layer.cornerCurve = .continuous

        controlView.backgroundColor = .white
        controlContainerView.frame = controlFrame
        controlView.frame = controlContainerView.bounds
        controlView.layer.cornerRadius = controlFrame.height / 2.0

        glassViewContainer.layer.shadowColor = UIColor.black.cgColor
        glassViewContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        glassViewContainer.layer.shadowRadius = 4
        glassViewContainer.layer.shadowOpacity = 0.1
        glassViewContainer.layer.cornerCurve = .continuous

        glassViewContainer.alpha = 0

        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(onGesture(_:)))
        gesture.minimumPressDuration = 0
        addGestureRecognizer(gesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(onPanGesture(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)

        self.gesture = gesture
        self.panGesture = panGesture

        self.dynamicSystem = DynamicSystem(f: 2, z: 0.5, r: 0) { [weak self] in
            guard let self, let dynamicSystem else { return }
            let scale = max(-1, min(1, (((dynamicSystem.x - dynamicSystem.y) / 50.0))))

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            controlContainerView.layer.sublayerTransform = CATransform3DMakeScale(1 + 0.15 * scale, 1 / (1 + 0.15 * scale), 1)
            CATransaction.commit()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        foregroundLine.layer.cornerRadius = foregroundLine.frame.height / 2.0

        backgroundLine.frame = CGRect(x: 0, y: frame.height / 2.0 - 3, width: frame.width, height: 6)
        backgroundLine.layer.cornerRadius = backgroundLine.frame.height / 2.0
        backgroundLine.layer.masksToBounds = true

        dotsStackView.frame = CGRect(x: 16, y: backgroundLine.frame.maxY + 4, width: frame.width - 32, height: 4)
        updateDotsStackSpacing()

        if traitCollectionDidChanged {
            traitCollectionDidChanged = false
            controlContainerView.layer.position.x = controlFrame.center.x
            controlContainerView.layer.position.y = controlFrame.center.y
        }
    }

    public func setValue(_ value: CGFloat, animated: Bool) {
        progress = min(1, max(0, (value - minimumValue) / (maximumValue - minimumValue)))

        let changes = {
            self.controlContainerView.layer.position.x = self.controlFrame.center.x
            self.controlContainerView.layer.position.y = self.controlFrame.center.y
        }

        if animated {
            UIView.animate(withDuration: 0.3) {
                changes()
            }
        } else {
            changes()
        }
    }

    private func updateDotsStackSpacing() {
        if controlPointsCount > 2 {
            dotsStackView.spacing = (dotsStackView.frame.width - CGFloat(4 * controlPointsCount)) / CGFloat(controlPointsCount - 1)
        } else {
            dotsStackView.spacing = 0
        }
    }

    private var gestureStartPosition: CGPoint = .zero
    private var gestureLastPosition: CGPoint = .zero
    private var startProgress: CGFloat = 0
    private var wasGestureStarted: Bool = false

    private var traitCollectionDidChanged: Bool = false

    @objc private func onGesture(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)

        switch gesture.state {
        case .began:
            if !controlView.bounds.contains(gesture.location(in: controlView)) {
                gesture.isEnabled = false
                gesture.isEnabled = true
                wasGestureStarted = false
                return
            } else {
                wasGestureStarted = true
            }

            feedbackGenerator.prepare()

            gestureStartPosition = location
            gestureLastPosition = location

            dynamicSystem?.start(value: controlFrame.center.x)
            startProgress = progress

            startValue = value

            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 1, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.controlContainerView.transform = .identity.scaledBy(x: 1.5, y: 1.5)
                self.controlContainerView.layer.position.x = self.controlFrame.center.x
                self.controlContainerView.layer.position.y = self.controlFrame.center.y
            }

            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.controlView.alpha = 0
                self.glassView.alpha = 1
                self.glassViewContainer.alpha = 1
            }
        case .changed:
            break
        case .ended, .failed, .cancelled:
            wasGestureStarted = false

            let lastValue = limitValueChangedToLatestState ? startValue : value
            progress = finalProgress(for: progress)

            if lastValue != value { onUpdate?(value) }

            dynamicSystem?.stop()

            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 1, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.controlContainerView.transform = .identity
                self.controlContainerView.layer.sublayerTransform = CATransform3DIdentity
                self.updateForegroundLineFrame(for: self.progress)
                self.controlContainerView.layer.position.x = self.controlFrame.center.x
                self.controlContainerView.layer.position.y = self.controlFrame.center.y
            }

            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.controlView.alpha = 1
                self.glassView.alpha = 0
                self.glassViewContainer.alpha = 0
            }
        case .recognized, .possible:
            break
        default:
            break
        }
    }

    @objc private func onPanGesture(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)

        switch gesture.state {
        case .began:
            break
        case .changed:
            let offset = location.x - gestureStartPosition.x;

            let lastValue = value
            progress = min(1, max(0, startProgress + offset / (frame.width - 32)))

            if lastValue != value {
                if controlPointsCount != 0 {
                    feedbackGenerator.impactOccurred()
                }

                if !limitValueChangedToLatestState {
                    onUpdate?(value)
                }
            }

            self.controlContainerView.layer.position.x = controlFrame.center.x
            self.controlContainerView.layer.position.y = controlFrame.center.y
            dynamicSystem?.updateInput(x: controlFrame.center.x)

            glassView.setNeedsDisplay()
            gestureLastPosition = location
        case .ended, .failed, .cancelled:
            break
        case .recognized, .possible:
            break
        default:
            break
        }
    }

    private func updateForegroundLineFrame(for progress: CGFloat) {
        let percent = 0.03
        let progress = interpolatedProgress(for: progress)

        foregroundLine.frame = CGRect(
            x: 0.0,
            y: 0.0,
            width: (frame.width - 38) * max(0, min(1, progress)) + 19 * max(0, min(1, progress / percent)) + 19 * max(0, min(1, (progress - (1 - percent)) / percent)),
            height: 6.0
        )
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass ||
           traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            traitCollectionDidChanged = true
        }
    }
}

extension CustomSliderView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGesture {
            return wasGestureStarted
        } else {
            return true
        }
    }
}
