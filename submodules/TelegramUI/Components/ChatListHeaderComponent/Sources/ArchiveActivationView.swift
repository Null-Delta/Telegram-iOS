//
//  ArchiveActivationView.swift
//  ChatListHeaderComponent
//
//  Created by Rustam on 01.09.2023.
//

import Foundation
import UIKit
import AnimationUI
import Display
import AsyncDisplayKit
import Lottie

public class ArchiveActivationView: UIView {
    private var animationDuration = 0.5
    
    private var archiveAvatarNode: ASDisplayNode? = nil
    private var wasTouchEnd: Bool = false
    
    private var safeAreaOffset = UIApplication.shared.windows[0].safeAreaInsets.left
    
    private var currentScrollOffset: CGFloat = 0

    public var isArchiveShown: Bool = false {
        didSet {
            if isArchiveShown {
                self.isActivated = false
                
                self.arrowNode.setColors(colors: [
                    "Arrow 2.Arrow 2.Stroke 1": UIColor(rgb: 0x4EB9F7),
                    "Arrow 1.Arrow 1.Stroke 1": UIColor(rgb: 0x4EB9F7),
                ])
                
                ArchiveShowProvider.isArchiveAnimating = true
                self.arrowView.play()

                unactivateGradientLayer.opacity = 0
                
                self.activateGradientLayer.animateSpring(
                    from: CGSize(width: self.frame.size.width * 2, height: self.frame.size.width * 2) as NSValue,
                    to: CGSize(width: ArchiveShowProvider.avatarSize, height: ArchiveShowProvider.avatarSize) as NSValue,
                    keyPath: "bounds.size",
                    duration: animationDuration,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false,
                    completion: { isFinish in
                        if self.isArchiveShown && isFinish {
                            self.archiveAvatarNode?.alpha = 1
                            //self.arrowView.alpha = 0
                            //self.activateView.alpha = 0
                            ArchiveShowProvider.isArchiveShown = true
                            ArchiveShowProvider.isArchiveAnimating = false
                            self.frame.size.height = 0
                        }
                    }
                )
                
                self.activateGradientLayer.animateSpring(
                    from: CATransform3DIdentity as NSValue,
                    to: CATransform3DRotate(CATransform3DIdentity, -CGFloat.pi / 2, 0, 0, 1) as NSValue,
                    keyPath: "transform",
                    duration: animationDuration,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                
                self.activateGradientLayer.animateSpring(
                    from: CGPoint(x: 0.4, y: 0.5) as NSValue,
                    to: CGPoint(x: 0, y: 0.5) as NSValue,
                    keyPath: "startPoint",
                    duration: animationDuration,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )

                self.activateViewContainer.layer.animateSpring(
                    from: 0 as NSValue,
                    to: -18 + (60 - ArchiveShowProvider.avatarSize) as NSValue,
                    keyPath: "position.y",
                    duration: animationDuration,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false,
                    additive: true
                )
                
                self.capsuleBackgroundView.layer.animateSpring(
                    from: self.capsuleBackgroundView.frame.height as NSValue,
                    to: 20 as NSValue,
                    keyPath: "bounds.size.height",
                    duration: animationDuration,
                    initialVelocity: 0.0,
                    damping: 110
                )

                self.capsuleBackgroundView.alpha = 0
                self.capsuleBackgroundView.layer.animateAlpha(from: 1, to: 0, duration: 0.2)
                self.capsuleBackgroundView.layer.animateSpring(
                    from: self.capsuleBackgroundView.layer.position.y as NSValue,
                    to: 38 as NSValue,
                    keyPath: "position.y",
                    duration: animationDuration,
                    initialVelocity: 0.0,
                    damping: 110
                )

                self.activateGradientLayer.animateSpring(
                    from: self.frame.size.width as NSValue,
                    to: ArchiveShowProvider.avatarSize / 2 as NSValue,
                    keyPath: "cornerRadius",
                    duration: animationDuration,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                
                self.activeLabel.alpha = 0
                self.unactiveLabel.alpha = 0
                self.activeLabel.layer.animateAlpha(from: 1, to: 0, duration: 0.2)
                self.unactiveLabel.layer.animateAlpha(from: 1, to: 0, duration: 0.2)
                
                self.arrowView.layer.animateSpring(from: 0 as NSValue, to: 5 as NSValue, keyPath: "position.y", duration: animationDuration, removeOnCompletion: false, additive: true)
            }
        }
    }
    
    private var isActivated: Bool = false {
        didSet {
            guard !isArchiveShown, !wasTouchEnd else { return }
            
            if isActivated {
                self.activateGradientLayer.animateSpring(
                    from: CGSize(width: 20, height: 20) as NSValue,
                    to: CGSize(width: self.frame.size.width * 2, height: self.frame.size.width * 2) as NSValue,
                    keyPath: "bounds.size",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                
                self.activateGradientLayer.animateSpring(
                    from: CGPoint(x: 0, y: 0.5) as NSValue,
                    to: CGPoint(x: 0.4, y: 0.5) as NSValue,
                    keyPath: "startPoint",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                
                self.activateGradientLayer.animateSpring(
                    from: 10 as NSValue,
                    to: self.frame.size.width as NSValue,
                    keyPath: "cornerRadius",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )

                self.unactiveLabel.layer.animateSpring(
                    from: CATransform3DIdentity as NSValue,
                    to: CATransform3DTranslate(CATransform3DIdentity, self.frame.size.width, 0, 0) as NSValue,
                    keyPath: "transform",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                self.unactiveLabel.alpha = 0
                self.unactiveLabel.layer.animateAlpha(from: 1, to: 0, duration: 0.25)
                
                self.activeLabel.layer.animateSpring(
                    from: CATransform3DTranslate(CATransform3DIdentity, -self.frame.size.width, 0, 0) as NSValue,
                    to: CATransform3DIdentity as NSValue,
                    keyPath: "transform",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                self.activeLabel.alpha = 1
                self.activeLabel.layer.animateAlpha(from: 0, to: 1, duration: 0.25)
                
                self.arrowView.layer.animateSpring(
                    from: CATransform3DRotate(CATransform3DIdentity, CGFloat.pi, 0, 0, 1) as NSValue,
                    to: CATransform3DIdentity as NSValue,
                    keyPath: "transform",
                    duration: 0.4,
                    removeOnCompletion: false
                )

                self.arrowNode.setColors(colors: [
                    "Arrow 2.Arrow 2.Stroke 1": UIColor(rgb: 0x2a9ef1),
                    "Arrow 1.Arrow 1.Stroke 1": UIColor(rgb: 0x2a9ef1),
                ])

            } else {
                self.activateGradientLayer.animateSpring(
                    from: CGSize(width: self.frame.size.width * 2, height: self.frame.size.width * 2) as NSValue,
                    to: CGSize(width: 20, height: 20) as NSValue,
                    keyPath: "bounds.size",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                
                self.activateGradientLayer.animateSpring(
                    from: CGPoint(x: 0.4, y: 0.5) as NSValue,
                    to: CGPoint(x: 0, y: 0.5) as NSValue,
                    keyPath: "startPoint",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                
                self.activateGradientLayer.animateSpring(
                    from: self.frame.size.width as NSValue,
                    to: 10 as NSValue,
                    keyPath: "cornerRadius",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                
                self.unactiveLabel.layer.animateSpring(
                    from: CATransform3DTranslate(CATransform3DIdentity, self.frame.size.width, 0, 0) as NSValue,
                    to: CATransform3DIdentity as NSValue,
                    keyPath: "transform",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                self.unactiveLabel.alpha = 1
                self.unactiveLabel.layer.animateAlpha(from: 0, to: 1, duration: 0.25)

                self.activeLabel.layer.animateSpring(
                    from: CATransform3DIdentity as NSValue,
                    to: CATransform3DTranslate(CATransform3DIdentity, -self.frame.size.width, 0, 0) as NSValue,
                    keyPath: "transform",
                    duration: 0.4,
                    initialVelocity: 0.0,
                    damping: 110,
                    removeOnCompletion: false
                )
                self.activeLabel.alpha = 0
                self.activeLabel.layer.animateAlpha(from: 1, to: 0, duration: 0.25)
                
                self.arrowView.layer.animateSpring(
                    from: CATransform3DIdentity as NSValue,
                    to: CATransform3DRotate(CATransform3DIdentity, CGFloat.pi, 0, 0, 1) as NSValue,
                    keyPath: "transform",
                    duration: 0.4,
                    removeOnCompletion: false
                )
                
                self.arrowNode.setColors(colors: [
                    "Arrow 2.Arrow 2.Stroke 1": UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
                    "Arrow 1.Arrow 1.Stroke 1": UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
                ])
            }
        }
    }
    
    func updateSize(newSize: CGSize, ignoreArchive: Bool = false) {
        safeAreaOffset = UIApplication.shared.windows[0].safeAreaInsets.left > 0 ? 44 : 0
        
        self.mainContainer.frame.size = CGSize(width: newSize.width, height: newSize.height + (isArchiveShown && !ignoreArchive ? ArchiveShowProvider.listItemSize: 0))
        self.frame.size = CGSize(width: newSize.width, height: newSize.height + (isArchiveShown && !ignoreArchive ? ArchiveShowProvider.listItemSize : 0))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        unactivateGradientLayer.frame = self.bounds
        CATransaction.commit()

        if !isArchiveShown && !wasTouchEnd && ArchiveShowProvider.isScrollContinue {
            if frame.size.height >= ArchiveShowProvider.listItemSize && !isActivated {
                isActivated = true
                ArchiveShowProvider.canPlayArchiveAnimation = true
                HapticFeedback().impact(.medium)
            } else if frame.size.height < ArchiveShowProvider.listItemSize && isActivated {
                isActivated = false
                ArchiveShowProvider.canPlayArchiveAnimation = false
                HapticFeedback().impact(.medium)
            }
            
            capsuleBackgroundView.frame.size.height = max(20, frame.size.height - 20)
            
            capsuleBackgroundView.frame.origin.y = frame.size.height - capsuleBackgroundView.frame.size.height - 10
            capsuleBackgroundView.frame.origin.x = (ArchiveShowProvider.avatarSize + 20) / 2 - 10 + safeAreaOffset
        }
        
        
        activateViewContainer.frame.origin = CGPoint(
            x: (ArchiveShowProvider.avatarSize + 20) / 2 - activateViewContainer.frame.width / 2 + safeAreaOffset,
            y:  frame.size.height - activateViewContainer.frame.height / 2 - 20
        )
        
        unactiveLabel.frame.origin.x = frame.size.width / 2 - unactiveLabel.frame.width / 2
        unactiveLabel.frame.origin.y = frame.size.height - 10 - unactiveLabel.frame.height

        activeLabel.frame.origin.x = frame.size.width / 2 - activeLabel.frame.width / 2
        activeLabel.frame.origin.y = frame.size.height - 10 - activeLabel.frame.height
    }
    
    lazy private var capsuleBackgroundView: UIView = {
        let view = UIView()
        view.frame.size.width = 20
        view.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        view.layer.cornerRadius = 10
        
        return view
    }()
    
    lazy private var mainContainer: UIView = {
        let view = UIView()
        
        return view
    }()
    
    lazy private var activateView: UIView = {
        let view = UIView()
        view.frame.size = CGSize(width: 20, height: 20)
        view.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 1, alpha: 1)
        view.layer.cornerRadius = 10
        
        view.layer.addSublayer(activateGradientLayer)
        activateGradientLayer.frame = view.bounds
        
        return view
    }()
    
    lazy private var activateGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.colors = [
            UIColor(rgb: 0x2a9ef1).cgColor,
            UIColor(rgb: 0x72d5fd).cgColor
        ]
        layer.type = .axial
        layer.cornerRadius = 10
        
        return layer
    }()
    
    lazy private var unactivateGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.colors = [
            UIColor(rgb: 0xb1b1b1).cgColor,
            UIColor(rgb: 0xcdcdcd).cgColor
        ]
        layer.type = .axial
        
        return layer
    }()
    
    lazy private var activateViewContainer: UIView = {
        let view = UIView()
        view.frame.size = CGSize(width: 20, height: 20)
        
        return view
    }()
    
    lazy private var unactiveLabel: UILabel = {
        let view = UILabel()
        view.text = "Swipe down for archive"
        view.font = .systemFont(ofSize: 16, weight: .semibold)
        view.textColor = .white

        view.frame.size = ("Swipe down for archive" as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 16, weight: .semibold)])
        
        
        return view
    }()
    
    lazy private var activeLabel: UILabel = {
        let view = UILabel()
        view.text = "Release for archive"
        view.font = .systemFont(ofSize: 16, weight: .semibold)
        view.textColor = .white
        
        view.frame.size = ("Release for archive" as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 16, weight: .semibold)])
        view.alpha = 0
        
        return view
    }()
    
    lazy private var arrowNode: AnimationNode = {
        AnimationNode(animation: "archive", colors: [
            "Cap.cap2.Fill 1": UIColor.white,
            "Cap.cap1.Fill 1": UIColor.white,
            "Box.box1.Fill 1": UIColor.white,
            "Box.box2.Fill 1": UIColor.white,
            "Arrow 2.Arrow 2.Stroke 1": UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
            "Arrow 1.Arrow 1.Stroke 1": UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
        ], scale: 1)

    }()
    lazy private var arrowView: AnimationView = {
        return arrowNode.animationView()!
    }()
    
    init() {
        super.init(frame: .zero)
        
        addSubview(mainContainer)

        mainContainer.layer.addSublayer(unactivateGradientLayer)
        
        mainContainer.addSubview(activateViewContainer)

        activateViewContainer.addSubview(activateView)
        mainContainer.addSubview(capsuleBackgroundView)
        mainContainer.addSubview(unactiveLabel)
        mainContainer.addSubview(activeLabel)
        
        arrowView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.57)
        
        let yOffset = floor(5.0 / 60.0 * ArchiveShowProvider.avatarSize)
        // 60 = 5; 56 = 4.66
        arrowView.frame = CGRect(origin: CGPoint(x: -(ArchiveShowProvider.avatarSize - 20) / 2, y: -(ArchiveShowProvider.avatarSize - 20) / 2 - yOffset), size: CGSize(width: ArchiveShowProvider.avatarSize, height: ArchiveShowProvider.avatarSize))
        activateViewContainer.addSubview(arrowView)
        arrowView.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat.pi, 0, 0, 1)
        
        clipsToBounds = true
        layer.masksToBounds = true
        ArchiveShowProvider.addObserver(observer: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func resetView() {
        self.frame.size.height = 0
        
        mainContainer.layer.removeAllAnimations()
        mainContainer.frame.origin.y = 0
        
        unactiveLabel.layer.removeAllAnimations()
        unactiveLabel.alpha = 1
        
        activeLabel.layer.removeAllAnimations()
        activateView.alpha = 1
        
        capsuleBackgroundView.layer.removeAllAnimations()
        capsuleBackgroundView.alpha = 1
        
        activateGradientLayer.removeAllAnimations()
        activateGradientLayer.opacity = 1
        activateGradientLayer.frame = CGRect(origin: .zero, size: CGSize(width: 20, height: 20))
        activateGradientLayer.cornerRadius = 10

        activateViewContainer.layer.removeAllAnimations()
        activateViewContainer.frame.size = CGSize(width: 20, height: 20)
        activateViewContainer.frame.origin = .zero
        
        arrowNode = AnimationNode(animation: "archive", colors: [
            "Cap.cap2.Fill 1": UIColor.white,
            "Cap.cap1.Fill 1": UIColor.white,
            "Box.box1.Fill 1": UIColor.white,
            "Box.box2.Fill 1": UIColor.white,
            "Arrow 2.Arrow 2.Stroke 1": UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
            "Arrow 1.Arrow 1.Stroke 1": UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1),
        ], scale: 1)
        
        arrowView.removeFromSuperview()
        arrowView = arrowNode.animationView()!
        
        arrowView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.57)
        
        let yOffset = floor(5.0 / 60.0 * ArchiveShowProvider.avatarSize)
        // 60 = 5; 56 = 4.66
        arrowView.frame = CGRect(origin: CGPoint(x: -(ArchiveShowProvider.avatarSize - 20) / 2, y: -(ArchiveShowProvider.avatarSize - 20) / 2 - yOffset), size: CGSize(width: ArchiveShowProvider.avatarSize, height: ArchiveShowProvider.avatarSize))
        activateViewContainer.addSubview(arrowView)
        arrowView.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat.pi, 0, 0, 1)

        unactivateGradientLayer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        unactivateGradientLayer.opacity = 1
        CATransaction.commit()
    }
}

extension ArchiveActivationView: ArchiveShowObserverProtocol {
    public func archiveShown() {
        wasTouchEnd = true
    }
    
    public func archiveNodeCreated(node: ASDisplayNode) {
        archiveAvatarNode = node.subnodes?[2].subnodes?[1].subnodes?[0]

        if !isArchiveShown {
            isArchiveShown = true
            if isActivated {
                archiveAvatarNode?.alpha = 0
            }
        }
    }
    
    public func archiveNodeHidden(node: ASDisplayNode) {
        isArchiveShown = false
        wasTouchEnd = false
        ArchiveShowProvider.isArchiveAddOffset = false
        resetView()
    }
    
    public func archiveSizeChanged() {
        
    }
    
    public func scrollChanged(offset: CGFloat) {
        currentScrollOffset = offset - 52
        
        mainContainer.frame.origin.y = min(0, -currentScrollOffset)
    }
}
